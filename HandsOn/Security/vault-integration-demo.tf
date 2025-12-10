# HashiCorp Vault Integration Demo
# Demonstrates using Vault with Terraform for dynamic secrets, encryption, and credential management

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = ">= 3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ============================================================================
# VAULT PROVIDER CONFIGURATION
# ============================================================================

# ✓ GOOD: Using environment variable for token
provider "vault" {
  address = var.vault_address
  # Token passed via VAULT_TOKEN environment variable
  # token = var.vault_token  # Not recommended (hardcoded)
}

# ✗ BAD: Hardcoded token (never do this)
# provider "vault" {
#   address = "https://vault.example.com:8200"
#   token = "s.XXXXXXXXXXXXXXXX"  # ✗ Never hardcode!
# }

provider "aws" {
  region = "us-east-1"
}

# ============================================================================
# PATTERN 1: STATIC SECRETS (KEY-VALUE)
# ============================================================================

resource "vault_generic_secret" "database_password" {
  path      = "secret/data/prod/database"
  data_json = jsonencode({
    username = "admin"
    password = random_password.db_password.result
    host     = aws_db_instance.example.endpoint
    port     = 5432
  })
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_db_instance" "example" {
  identifier       = "example-db"
  engine           = "postgres"
  engine_version   = "15.2"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
  
  username = "admin"
  password = random_password.db_password.result
  
  skip_final_snapshot = true
}

# ✓ Read secret from Vault
data "vault_generic_secret" "database" {
  path = vault_generic_secret.database_password.path
}

# Use secret in application
resource "aws_secretsmanager_secret" "db_from_vault" {
  name = "prod/database-from-vault"
}

resource "aws_secretsmanager_secret_version" "db_from_vault" {
  secret_id = aws_secretsmanager_secret.db_from_vault.id
  secret_string = jsonencode({
    username = data.vault_generic_secret.database.data["username"]
    password = data.vault_generic_secret.database.data["password"]
    host     = data.vault_generic_secret.database.data["host"]
  })
}

# ============================================================================
# PATTERN 2: DYNAMIC DATABASE CREDENTIALS
# ============================================================================

# Configure Vault database secret engine
# (This would be done outside Terraform in most cases)

resource "vault_database_secret_backend" "postgres" {
  path = "database"
}

resource "vault_database_secret_backend_connection" "postgres" {
  backend       = vault_database_secret_backend.postgres.path
  name          = "postgres"
  allowed_roles = ["readonly"]

  postgresql {
    connection_url = "postgresql://{{username}}:{{password}}@${aws_db_instance.example.endpoint}/postgres"
    username       = "vault"
    password       = random_password.vault_db_password.result
  }
}

resource "random_password" "vault_db_password" {
  length  = 32
  special = true
}

resource "vault_database_secret_backend_role" "readonly" {
  backend             = vault_database_secret_backend.postgres.path
  name                = "readonly"
  db_name             = vault_database_secret_backend_connection.postgres.name
  creation_statements = [
    "CREATE USER \"{{name}}\" WITH PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"
  ]
  default_ttl = 3600
  max_ttl     = 7200
}

# ✓ Get dynamic database credentials from Vault
data "vault_database_static_account_credentials" "postgres" {
  backend = vault_database_secret_backend.postgres.path
  role    = vault_database_secret_backend_role.readonly.name
}

# ============================================================================
# PATTERN 3: AWS SECRETS ENGINE
# ============================================================================

# Generate temporary AWS credentials via Vault
resource "vault_aws_secret_backend" "aws" {
  path                      = "aws"
  access_key                = aws_iam_access_key.vault.id
  secret_key                = aws_iam_access_key.vault.secret
  region                    = "us-east-1"
  iam_endpoint              = null
  sts_endpoint              = null
}

resource "aws_iam_user" "vault" {
  name = "vault-credential-generator"
}

resource "aws_iam_access_key" "vault" {
  user = aws_iam_user.vault.name
}

resource "aws_iam_user_policy" "vault" {
  name   = "vault-policy"
  user   = aws_iam_user.vault.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole",
          "ec2:*",
          "s3:*"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "vault_aws_secret_backend_role" "s3_role" {
  backend         = vault_aws_secret_backend.aws.path
  name            = "s3-access"
  credential_type = "iam_user"
  policy_arns = [
    aws_iam_policy.vault_s3.arn
  ]
}

resource "aws_iam_policy" "vault_s3" {
  name   = "vault-s3-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = "*"
      }
    ]
  })
}

# ✓ Get temporary AWS credentials from Vault
data "vault_aws_access_credentials" "s3" {
  backend = vault_aws_secret_backend.aws.path
  role    = vault_aws_secret_backend_role.s3_role.name
}

# ============================================================================
# PATTERN 4: PKI SECRETS ENGINE (CERTIFICATES)
# ============================================================================

resource "vault_pki_secret_backend" "pki" {
  path                    = "pki"
  max_lease_ttl_seconds   = 315360000
  default_lease_ttl_seconds = 2592000
}

resource "vault_pki_secret_backend_config_urls" "config_urls" {
  backend                 = vault_pki_secret_backend.pki.path
  issuing_certificates   = ["${var.vault_address}:8200/v1/${vault_pki_secret_backend.pki.path}/ca"]
  crl_distribution_points = ["${var.vault_address}:8200/v1/${vault_pki_secret_backend.pki.path}/crl"]
}

resource "vault_pki_secret_backend_self_signed_cert" "root" {
  backend            = vault_pki_secret_backend.pki.path
  type               = "root"
  common_name        = "example.com"
  ttl                = "87600h"
  ou                 = "Engineering"
  organization       = "Example Corp"
  country            = "US"
}

resource "vault_pki_secret_backend_role" "certificate" {
  backend      = vault_pki_secret_backend.pki.path
  name         = "example.com"
  ttl          = "8760h"
  max_ttl      = "17520h"
  require_cn   = true
  allowed_domains = ["example.com", "*.example.com"]
  allow_subdomains = true
  generate_lease = true
}

# ✓ Generate certificate from Vault
data "vault_pki_secret_backend_sign" "certificate" {
  backend = vault_pki_secret_backend.pki.path
  name    = vault_pki_secret_backend_role.certificate.name
  
  common_name = "api.example.com"
  ttl         = "8760h"
}

# Use certificate in AWS
resource "aws_acm_certificate" "from_vault" {
  private_key             = data.vault_pki_secret_backend_sign.certificate.private_key
  certificate_body        = data.vault_pki_secret_backend_sign.certificate.certificate
  certificate_chain       = data.vault_pki_secret_backend_sign.certificate.ca_chain
  
  tags = {
    Name = "vault-certificate"
  }
}

# ============================================================================
# PATTERN 5: GENERIC SECRET BACKEND (KEY-VALUE)
# ============================================================================

# Create KV secrets engine (v2)
resource "vault_mount" "kv" {
  path        = "kv"
  type        = "kv-v2"
  description = "KV v2 secret engine"
}

# Store API key
resource "vault_kv_secret_v2" "api_key" {
  mount               = vault_mount.kv.path
  name                = "prod/api-keys"
  delete_all_versions = true
  
  data_json = jsonencode({
    stripe_key = random_password.stripe_key.result
    twilio_key = random_password.twilio_key.result
  })
}

resource "random_password" "stripe_key" {
  length  = 32
  special = false
}

resource "random_password" "twilio_key" {
  length  = 32
  special = false
}

# ✓ Retrieve secret
data "vault_kv_secret_v2" "api_keys" {
  mount = vault_mount.kv.path
  name  = vault_kv_secret_v2.api_key.name
}

# ============================================================================
# PATTERN 6: VAULT POLICIES & AUTH
# ============================================================================

# ✓ Create application policy (least privilege)
resource "vault_policy" "app_policy" {
  name = "app-policy"
  
  policy = <<EOT
path "kv/data/prod/*" {
  capabilities = ["read", "list"]
}

path "database/static-creds/readonly" {
  capabilities = ["read"]
}

path "aws/creds/s3-access" {
  capabilities = ["read"]
}
EOT
}

# AppRole auth method (for applications)
resource "vault_approle_auth_backend_role" "app" {
  backend   = "approle"
  role_name = "terraform-app"
  
  bind_secret_id      = true
  bind_secret_id_ttl  = "60m"
  token_ttl           = "1h"
  token_max_ttl       = "24h"
  secret_id_ttl       = "15m"
  secret_id_num_uses  = 50
  policies            = [vault_policy.app_policy.name]
}

resource "vault_approle_auth_backend_role_secret_id" "app" {
  backend   = "approle"
  role_name = vault_approle_auth_backend_role.app.role_name
}

# Get AppRole credentials for CI/CD
data "vault_approle_auth_backend_role_id" "app" {
  backend   = "approle"
  role_name = vault_approle_auth_backend_role.app.role_name
}

# ============================================================================
# PATTERN 7: VAULT ENCRYPTION (TRANSIT ENGINE)
# ============================================================================

resource "vault_mount" "transit" {
  path        = "transit"
  type        = "transit"
  description = "Transit encryption engine"
}

resource "vault_transit_secret_backend_key" "encryption_key" {
  backend = vault_mount.transit.path
  name    = "application-data"
  
  deletion_allowed = false
  exportable       = false
}

# ✓ Encrypt data with Vault
data "vault_transit_encrypt" "sensitive_data" {
  backend      = vault_mount.transit.path
  key_name     = vault_transit_secret_backend_key.encryption_key.name
  plaintext    = base64encode("sensitive-customer-data")
}

# Decrypt data
data "vault_transit_decrypt" "sensitive_data" {
  backend      = vault_mount.transit.path
  key_name     = vault_transit_secret_backend_key.encryption_key.name
  ciphertext   = data.vault_transit_encrypt.sensitive_data.ciphertext
}

# ============================================================================
# PATTERN 8: VAULT AUDIT LOGGING
# ============================================================================

# Enable audit logging (for compliance)
resource "vault_audit" "file" {
  type = "file"
  
  options = {
    file_path = "/var/log/vault/audit.log"
  }
}

resource "vault_audit" "syslog" {
  type = "syslog"
  
  options = {
    facility = "LOCAL0"
    tag      = "vault"
  }
}

# ============================================================================
# VARIABLES
# ============================================================================

variable "vault_address" {
  description = "Vault server address"
  type        = string
  default     = "http://localhost:8200"
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "database_credentials" {
  value = {
    username = data.vault_generic_secret.database.data["username"]
    host     = data.vault_generic_secret.database.data["host"]
  }
  sensitive = true
  description = "Database credentials from Vault"
}

output "dynamic_db_credentials" {
  value = {
    username = try(data.vault_database_static_account_credentials.postgres.username, "")
    # Note: password expires after TTL
  }
  sensitive = true
  description = "Dynamic database credentials from Vault"
}

output "aws_s3_access_credentials" {
  value = {
    access_key = try(data.vault_aws_access_credentials.s3.access_key, "")
    # Note: secret key and lease info also available
  }
  sensitive = true
  description = "Temporary AWS S3 credentials from Vault"
}

output "certificate" {
  value = {
    common_name = data.vault_pki_secret_backend_sign.certificate.common_name
    certificate_arn = try(aws_acm_certificate.from_vault.arn, "")
  }
  description = "Certificate from Vault PKI"
}

output "api_keys" {
  value = {
    stripe = try(data.vault_kv_secret_v2.api_keys.data["stripe_key"], "")
    twilio = try(data.vault_kv_secret_v2.api_keys.data["twilio_key"], "")
  }
  sensitive = true
  description = "API keys from Vault"
}

output "approle_role_id" {
  value       = data.vault_approle_auth_backend_role_id.app.role_id
  description = "AppRole Role ID for CI/CD"
}

output "approle_secret_id" {
  value       = vault_approle_auth_backend_role_secret_id.app.secret_id
  sensitive   = true
  description = "AppRole Secret ID for CI/CD (expires in 15 min)"
}

# ============================================================================
# SETUP NOTES
# ============================================================================

# Starting Vault locally (development only):
# vault server -dev
#
# This creates an in-memory unseal key and root token.
# Access Vault at http://localhost:8200
#
# Export token:
# export VAULT_TOKEN="hvs...."
# export VAULT_ADDR="http://localhost:8200"
#
# Production Vault setup should use:
# - TLS certificates
# - Persistent storage backend (Consul, S3, etc)
# - Auto-unseal with KMS
# - HA setup
# - Audit logging enabled

# ============================================================================
