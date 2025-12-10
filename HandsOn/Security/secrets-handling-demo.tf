# Secrets Handling Demo
# Demonstrates secure secrets management in Terraform

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ============================================================================
# PATTERN 1: AWS SECRETS MANAGER (RECOMMENDED FOR AWS)
# ============================================================================

# Generate random password
resource "random_password" "db_password" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# Store in Secrets Manager
resource "aws_secretsmanager_secret" "database_password" {
  name = "prod/database/password"
  
  recovery_window_in_days = 7  # Allow recovery for 7 days
  
  tags = {
    Application = "MyApp"
    Secret      = "DatabasePassword"
  }
}

resource "aws_secretsmanager_secret_version" "database_password" {
  secret_id     = aws_secretsmanager_secret.database_password.id
  secret_string = random_password.db_password.result
}

# Database using generated password
resource "aws_db_instance" "main" {
  identifier       = "prod-database"
  engine           = "postgres"
  engine_version   = "15.2"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
  
  # Use generated password (not Terraform variable)
  username = "admin"
  password = random_password.db_password.result
  
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  
  backup_retention_period = 30
  multi_az                = true
  
  depends_on = [aws_secretsmanager_secret_version.database_password]
}

# Retrieve secret in application
# AWS SDK or runtime: 
# secret_client.get_secret_value(SecretId="prod/database/password")

# ============================================================================
# PATTERN 2: JSON SECRETS (MULTIPLE VALUES)
# ============================================================================

locals {
  database_secret = {
    username = "admin"
    password = random_password.db_password.result
    engine   = "postgres"
  }
}

resource "aws_secretsmanager_secret" "database_json" {
  name = "prod/database/credentials"
}

resource "aws_secretsmanager_secret_version" "database_json" {
  secret_id     = aws_secretsmanager_secret.database_json.id
  secret_string = jsonencode(local.database_secret)
}

# Application retrieves and parses JSON:
# secrets = json.loads(secret_client.get_secret_value(...)['SecretString'])

# ============================================================================
# PATTERN 3: PARAMETER STORE (FOR NON-SENSITIVE VALUES)
# ============================================================================

resource "aws_ssm_parameter" "app_config" {
  name        = "/prod/app/config"
  type        = "String"  # Regular parameter
  value       = "production"
  description = "Application configuration"
  
  tags = {
    Environment = "prod"
  }
}

# For sensitive values: use SecureString
resource "aws_ssm_parameter" "api_key" {
  name            = "/prod/app/api-key"
  type            = "SecureString"  # Encrypted by default
  value           = random_password.api_key.result
  key_id          = aws_kms_key.ssm.id  # Custom KMS key
  description     = "API key for external service"
  
  tags = {
    Sensitive = "true"
  }
}

resource "random_password" "api_key" {
  length  = 32
  special = true
}

# ============================================================================
# PATTERN 4: AVOID - TERRAFORM VARIABLES WITH DEFAULTS
# ============================================================================

# ✗ BAD: Hardcoded in code
# variable "db_password" {
#   type    = string
#   default = "MyPassword123"  # EXPOSED IN STATE!
# }

# ✓ BETTER: Variable without default (prompted at apply)
# variable "db_password" {
#   type        = string
#   description = "Database password"
#   sensitive   = true  # Hide from output
# }

# ✓ BEST: Use .tfvars file (not committed)
# # terraform.tfvars (in .gitignore)
# db_password = "MySecurePassword"

# ============================================================================
# PATTERN 5: TERRAFORM VARIABLE WITH SENSITIVE FLAG
# ============================================================================

variable "webhook_secret" {
  type        = string
  description = "Webhook signing secret"
  sensitive   = true  # Redact from output
}

# Usage: Mark variable as sensitive
# terraform apply -var="webhook_secret=abc123"

# Or use environment variable:
# TF_VAR_webhook_secret=abc123 terraform apply

# ============================================================================
# PATTERN 6: ENVIRONMENT VARIABLES FOR SECRETS
# ============================================================================

# PowerShell:
# $env:TF_VAR_db_password = "SecurePassword123"
# terraform apply

# Bash:
# export TF_VAR_db_password="SecurePassword123"
# terraform apply

# CI/CD (GitHub Actions):
# jobs:
#   terraform:
#     runs-on: ubuntu-latest
#     env:
#       TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
#     steps:
#       - run: terraform apply

# ============================================================================
# PATTERN 7: TERRAFORM CLOUD/ENTERPRISE VARIABLES
# ============================================================================

# Store sensitive variables in Terraform Cloud UI
# - Encrypted at rest
# - Encrypted in transit
# - Access controlled
# - Audit logged

# In workspace:
# - Mark as "Sensitive"
# - Not displayed in runs
# - Available to apply

# ============================================================================
# PATTERN 8: KMS ENCRYPTION FOR SENSITIVE OUTPUTS
# ============================================================================

# Mark outputs as sensitive (not shown in logs)
output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "Database endpoint (not sensitive)"
  sensitive   = false
}

# Sensitive outputs are redacted
output "database_master_username" {
  value       = aws_db_instance.main.username
  sensitive   = true  # Won't be shown
}

# ============================================================================
# SUPPORTING RESOURCES
# ============================================================================

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_key" "ssm" {
  description             = "KMS key for SSM"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# ============================================================================
# SECRETS BEST PRACTICES
# ============================================================================

# 1. NEVER hardcode secrets in .tf files
#    ✗ password = "MyPassword"
#    ✓ password = random_password.db.result

# 2. Add *.tfvars to .gitignore
#    # .gitignore
#    terraform.tfvars
#    terraform.tfvars.*

# 3. Use AWS Secrets Manager for:
#    - Database passwords
#    - API tokens
#    - Private keys
#    - OAuth credentials

# 4. Use Parameter Store (SecureString) for:
#    - Configuration values
#    - License keys
#    - Certificates

# 5. Use Terraform Cloud for team secrets:
#    - UI-managed sensitive variables
#    - Access control
#    - Audit logging
#    - Encryption

# 6. Mark variables as sensitive:
#    variable "secret" {
#      sensitive = true
#    }

# 7. Rotate secrets regularly:
#    - Set rotation on Secrets Manager
#    - Automatic key rotation
#    - Regular policy updates

# 8. Audit secret access:
#    - CloudTrail logging
#    - CloudWatch monitoring
#    - Access alerts

# ============================================================================
