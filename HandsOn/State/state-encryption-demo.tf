# State File Encryption Demo
# Demonstrates encrypting state files to protect sensitive data

terraform {
  required_version = ">= 1.0"

  # S3 backend with encryption enabled
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true  # Enable encryption at rest
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Example 1: S3 bucket encryption (stores state encrypted)
resource "aws_s3_bucket" "terraform_state" {
  bucket_prefix = "terraform-state-"

  tags = {
    Purpose = "Terraform state backend"
    Encryption = "AES-256"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # Server-side encryption with S3-managed keys
      # Alternative: "aws:kms" for KMS-managed keys
    }
  }
}

# Example 2: KMS key for encryption (stronger security)
resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Purpose = "Encrypt Terraform state"
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# Backend configuration using KMS:
# terraform {
#   backend "s3" {
#     bucket         = "my-terraform-state"
#     key            = "prod/terraform.tfstate"
#     region         = "us-east-1"
#     encrypt        = true
#     kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/12345678-1234-1234-1234-123456789012"
#     dynamodb_table = "terraform-locks"
#   }
# }

# Example 3: S3 bucket policy to enforce encryption
resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Example 4: Enable versioning for state file (backup/recovery)
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"  # Enables state recovery from previous versions
  }
}

# Example 5: Enable MFA delete protection (additional security)
# Note: Requires root account and special setup
# versioning_configuration {
#   status     = "Enabled"
#   mfa_delete = "Enabled"  # Requires MFA to delete versions
# }

# Example 6: Sensitive data in state (encrypted at rest)
variable "database_password" {
  description = "Database password (stored encrypted in state)"
  type        = string
  sensitive   = true  # Marks output as sensitive (not shown in logs)
}

resource "null_resource" "sensitive_example" {
  triggers = {
    # WARNING: This will be stored in state file (encrypted)
    # Use AWS Secrets Manager or Parameter Store instead for production
    db_password = var.database_password
  }
}

# Example 7: Terraform Cloud (automatic encryption)
# terraform {
#   cloud {
#     organization = "my-org"
#     workspaces {
#       name = "production"
#     }
#   }
# }
# # Terraform Cloud automatically encrypts state and secrets at rest

output "encryption_setup" {
  value = "State file encryption enabled. Sensitive data in state is encrypted at rest."
}

# ============================================================================
# STATE FILE ENCRYPTION BEST PRACTICES
# ============================================================================

# 1. ALWAYS use encrypted S3 backend
#    - Enable encrypt = true in S3 backend config
#    - Use KMS keys for stronger encryption than S3-managed keys

# 2. RESTRICT S3 bucket access
#    - Use bucket policies to restrict access
#    - Enable MFA delete protection
#    - Enable versioning for recovery

# 3. USE ENCRYPTION IN TRANSIT
#    - Terraform uses HTTPS for remote state
#    - Verify certificates are valid
#    - Use VPC endpoints for private connectivity

# 4. AVOID SENSITIVE DATA IN STATE
#    - Use AWS Secrets Manager for passwords/keys
#    - Use AWS Systems Manager Parameter Store for config
#    - Use AWS KMS for encryption keys
#    - Mark variables as sensitive = true

# 5. ROTATE ENCRYPTION KEYS
#    - Enable automatic key rotation on KMS keys
#    - Re-encrypt state periodically
#    - Plan key rotation in advance

# 6. AUDIT STATE ACCESS
#    - Enable S3 bucket logging
#    - Enable CloudTrail for API access logging
#    - Monitor access with CloudWatch

# 7. BACKUP STATE FILES
#    - Enable S3 versioning
#    - Implement lifecycle policies for archival
#    - Test recovery procedures regularly
#    - Store backups in different region/account

# 8. USE TERRAFORM CLOUD FOR TEAM ENVIRONMENTS
#    - Automatic state encryption and backup
#    - Access controls and audit logging
#    - State locking included
#    - State retention and recovery

# ============================================================================
# ENCRYPTION COMPARISON TABLE
# ============================================================================

# Local State:
#   Encryption: None (file on disk)
#   Backup:     Manual backup required
#   Sharing:    Not recommended (state is unencrypted)
#   Use case:   Local development only

# S3 Backend (AES-256):
#   Encryption: AES-256 (S3-managed keys)
#   Backup:     S3 versioning
#   Sharing:    Better (encrypted in transit and at rest)
#   Use case:   Team projects, small/medium deployments

# S3 Backend (KMS):
#   Encryption: KMS (customer or AWS-managed keys)
#   Backup:     S3 versioning + key rotation
#   Sharing:    Secure (encrypted with HSM-backed keys)
#   Use case:   Regulated environments, large deployments

# Terraform Cloud:
#   Encryption: AES-256 at rest, TLS in transit
#   Backup:     Automatic backup and versioning
#   Sharing:    Secure (role-based access control)
#   Use case:   Teams, enterprises, multi-cloud

# ============================================================================
