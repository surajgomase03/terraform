# KMS Encryption Demo
# Demonstrates AWS Key Management Service for encrypting infrastructure resources

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ============================================================================
# KMS KEY CREATION AND MANAGEMENT
# ============================================================================

# ============================================================================
# KEY 1: DATABASE ENCRYPTION KEY
# ============================================================================

resource "aws_kms_key" "database" {
  description             = "KMS key for RDS database encryption"
  deletion_window_in_days = 30  # Allow 30 days to recover if deleted
  enable_key_rotation     = true  # Auto-rotate yearly
  
  tags = {
    Name       = "database-key"
    Purpose    = "RDS Encryption"
    Environment = "prod"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/database-encryption"
  target_key_id = aws_kms_key.database.key_id
}

# ============================================================================
# KEY 2: S3 ENCRYPTION KEY
# ============================================================================

resource "aws_kms_key" "s3_storage" {
  description             = "KMS key for S3 encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  # Grant permissions for S3 to use key
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use the key"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "s3_storage" {
  name          = "alias/s3-encryption"
  target_key_id = aws_kms_key.s3_storage.key_id
}

# ============================================================================
# KEY 3: SECRETS MANAGER ENCRYPTION KEY
# ============================================================================

resource "aws_kms_key" "secrets" {
  description             = "KMS key for Secrets Manager"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow Secrets Manager to use key"
        Effect = "Allow"
        Principal = {
          Service = "secretsmanager.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "secrets" {
  name          = "alias/secrets-encryption"
  target_key_id = aws_kms_key.secrets.key_id
}

# ============================================================================
# KEY 4: TERRAFORM STATE ENCRYPTION KEY
# ============================================================================

resource "aws_kms_key" "terraform_state" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow S3 to use key for state encryption"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/terraform-state-encryption"
  target_key_id = aws_kms_key.terraform_state.key_id
}

# ============================================================================
# ENCRYPTED RDS DATABASE
# ============================================================================

resource "aws_db_instance" "encrypted" {
  identifier            = "encrypted-database"
  engine                = "postgres"
  engine_version        = "15.2"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  
  # ✓ Encryption configuration
  storage_encrypted = true
  kms_key_id        = aws_kms_key.database.arn
  
  # ✓ Additional security
  publicly_accessible = false
  multi_az            = true
  backup_retention_period = 30
  
  skip_final_snapshot   = false
  final_snapshot_identifier = "encrypted-database-final"
  
  # ✓ Credentials from Secrets Manager
  username = "admin"
  password = random_password.database.result
  
  tags = {
    Name       = "encrypted-database"
    Encryption = "KMS"
  }
}

resource "random_password" "database" {
  length  = 32
  special = true
}

# ============================================================================
# ENCRYPTED S3 BUCKET
# ============================================================================

resource "aws_s3_bucket" "encrypted" {
  bucket = "my-encrypted-bucket-${data.aws_caller_identity.current.account_id}"
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "encrypted" {
  bucket = aws_s3_bucket.encrypted.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted" {
  bucket = aws_s3_bucket.encrypted.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3_storage.arn
    }
    bucket_key_enabled = true  # Use S3 bucket key (cheaper)
  }
}

# Enable versioning
resource "aws_s3_bucket_versioning" "encrypted" {
  bucket = aws_s3_bucket.encrypted.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable MFA delete protection
# (Requires special configuration with root account)

# ============================================================================
# ENCRYPTED SECRETS MANAGER SECRET
# ============================================================================

resource "aws_secretsmanager_secret" "api_key" {
  name                    = "prod/api-key"
  kms_key_id              = aws_kms_key.secrets.id  # Use custom KMS key
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "api_key" {
  secret_id     = aws_secretsmanager_secret.api_key.id
  secret_string = random_password.api_key.result
}

resource "random_password" "api_key" {
  length  = 32
  special = true
}

# ============================================================================
# ENCRYPTED LOGS
# ============================================================================

resource "aws_cloudwatch_log_group" "encrypted" {
  name              = "/prod/application/logs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn  # Encrypt logs with KMS
  
  tags = {
    Name       = "application-logs"
    Encryption = "KMS"
  }
}

resource "aws_kms_key" "logs" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM policies"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:CreateGrant",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# KMS KEY MANAGEMENT
# ============================================================================

# Monitor key usage
resource "aws_cloudwatch_metric_alarm" "key_disabled" {
  alarm_name          = "kms-key-disabled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UserErrorCount"
  namespace           = "AWS/KMS"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Alert when KMS key has errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    KeyId = aws_kms_key.database.id
  }
}

resource "aws_sns_topic" "alerts" {
  name = "kms-alerts"
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# OUTPUTS
# ============================================================================

output "database_key_id" {
  value       = aws_kms_key.database.key_id
  description = "KMS key ID for database encryption"
}

output "s3_key_id" {
  value       = aws_kms_key.s3_storage.key_id
  description = "KMS key ID for S3 encryption"
}

output "encrypted_database_endpoint" {
  value       = aws_db_instance.encrypted.endpoint
  description = "Encrypted database endpoint"
}

output "encrypted_s3_bucket" {
  value       = aws_s3_bucket.encrypted.id
  description = "Encrypted S3 bucket name"
}

# ============================================================================
# KMS KEY ROTATION
# ============================================================================

# Manual key rotation (creates new version)
# AWS automatically rotates the key yearly if enabled

# Check key rotation status:
# aws kms get-key-rotation-status --key-id <key_id>

# Manually rotate:
# aws kms rotate-key --key-id <key_id>

# ============================================================================
# KEY POLICY EXAMPLES
# ============================================================================

# Allow specific IAM role to decrypt
# {
#   "Sid": "Allow Lambda to decrypt",
#   "Effect": "Allow",
#   "Principal": {
#     "AWS": "arn:aws:iam::ACCOUNT:role/lambda-role"
#   },
#   "Action": [
#     "kms:Decrypt",
#     "kms:DescribeKey"
#   ],
#   "Resource": "*"
# }

# Grant temporary permissions
# aws kms create-grant \
#   --key-id <key_id> \
#   --grantee-principal <role_arn> \
#   --operations Decrypt GenerateDataKey

# ============================================================================
