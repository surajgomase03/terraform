# tfsec Scanning Demo
# Demonstrates static analysis scanning of Terraform code for security issues

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
# SECURITY ISSUE 1: UNENCRYPTED S3 BUCKET (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: S3 bucket without encryption - tfsec will flag as aws-s3-enable-bucket-encryption
resource "aws_s3_bucket" "unencrypted" {
  bucket = "my-unencrypted-bucket"
  
  # Missing encryption configuration
}

# ✓ GOOD: S3 bucket with encryption enabled
resource "aws_s3_bucket" "encrypted" {
  bucket = "my-encrypted-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted" {
  bucket = aws_s3_bucket.encrypted.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # or "aws:kms" for customer-managed keys
    }
  }
}

# ============================================================================
# SECURITY ISSUE 2: UNRESTRICTED SECURITY GROUP (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: Security group allowing all traffic - tfsec will flag as aws-vpc-add-ingress-rule
resource "aws_security_group" "unrestricted" {
  name = "unrestricted-sg"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # ✗ Open to internet
  }
}

# ✓ GOOD: Security group with restricted access
resource "aws_security_group" "restricted" {
  name = "restricted-sg"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["10.0.0.0/8"]  # ✓ Restricted to internal CIDR
    security_groups = [aws_security_group.bastion.id]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]  # ✓ Restricted
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Egress usually okay
  }
}

resource "aws_security_group" "bastion" {
  name = "bastion-sg"
}

# ============================================================================
# SECURITY ISSUE 3: UNENCRYPTED RDS DATABASE (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: RDS without encryption - tfsec will flag as aws-rds-encrypt-instance-storage
resource "aws_db_instance" "unencrypted" {
  identifier            = "unencrypted-db"
  engine                = "postgres"
  engine_version        = "15.2"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  username              = "admin"
  password              = "password123"
  skip_final_snapshot   = true
  # Missing storage_encrypted = true
}

# ✓ GOOD: RDS with encryption enabled
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_db_instance" "encrypted" {
  identifier            = "encrypted-db"
  engine                = "postgres"
  engine_version        = "15.2"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  
  username            = "admin"
  password            = random_password.db.result
  skip_final_snapshot = false
  final_snapshot_identifier = "backup"
}

resource "random_password" "db" {
  length  = 32
  special = true
}

# ============================================================================
# SECURITY ISSUE 4: PUBLIC RDS DATABASE (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: RDS with public access - tfsec will flag as aws-rds-no-public-db
resource "aws_db_instance" "public_db" {
  identifier              = "public-db"
  engine                  = "mysql"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  username                = "admin"
  password                = "password123"
  publicly_accessible     = true  # ✗ Never public!
  skip_final_snapshot     = true
}

# ============================================================================
# SECURITY ISSUE 5: HARDCODED SECRETS (CRITICAL)
# ============================================================================

# ✗ BAD: Hardcoded password - tfsec will flag as general-secrets-found
resource "aws_secretsmanager_secret_version" "hardcoded" {
  secret_id     = aws_secretsmanager_secret.example.id
  secret_string = "hardcoded-password-12345"  # ✗ Never hardcode!
}

resource "aws_secretsmanager_secret" "example" {
  name = "example-secret"
}

# ✓ GOOD: Use random password or external data source
resource "aws_secretsmanager_secret" "app_secret" {
  name = "app-secret"
}

resource "aws_secretsmanager_secret_version" "app_secret" {
  secret_id     = aws_secretsmanager_secret.app_secret.id
  secret_string = random_password.app.result  # ✓ Generated securely
}

resource "random_password" "app" {
  length  = 32
  special = true
}

# ============================================================================
# SECURITY ISSUE 6: UNVERSIONED S3 BUCKET (MEDIUM SEVERITY)
# ============================================================================

# ✗ BAD: S3 without versioning - tfsec will flag as aws-s3-enable-versioning
resource "aws_s3_bucket" "no_versioning" {
  bucket = "my-no-versioning-bucket"
  # Missing versioning configuration
}

# ✓ GOOD: S3 with versioning enabled
resource "aws_s3_bucket" "with_versioning" {
  bucket = "my-versioned-bucket"
}

resource "aws_s3_bucket_versioning" "with_versioning" {
  bucket = aws_s3_bucket.with_versioning.id

  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================================================
# SECURITY ISSUE 7: S3 BUCKET WITH PUBLIC ACCESS (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: S3 bucket with public access - tfsec will flag as aws-s3-block-public-access
resource "aws_s3_bucket" "public_bucket" {
  bucket = "my-public-bucket"
}

# ✓ GOOD: S3 bucket with public access blocked
resource "aws_s3_bucket" "private_bucket" {
  bucket = "my-private-bucket"
}

resource "aws_s3_bucket_public_access_block" "private_bucket" {
  bucket = aws_s3_bucket.private_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ============================================================================
# SECURITY ISSUE 8: UNENCRYPTED EBS VOLUME (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: EBS volume without encryption - tfsec will flag as aws-ebs-encryption-by-default
resource "aws_ebs_volume" "unencrypted" {
  availability_zone = "us-east-1a"
  size              = 100
  # Missing encrypted = true
}

# ✓ GOOD: EBS volume with encryption
resource "aws_ebs_volume" "encrypted" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn
}

resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# ============================================================================
# SECURITY ISSUE 9: OVERLY PERMISSIVE IAM POLICY (HIGH SEVERITY)
# ============================================================================

# ✗ BAD: IAM policy with wildcard permissions - tfsec will flag as aws-iam-no-wildcard-actions
resource "aws_iam_policy" "overly_permissive" {
  name = "overly-permissive-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"  # ✗ Wildcard - too permissive!
        Resource = "*"
      }
    ]
  })
}

# ✓ GOOD: Least privilege IAM policy
resource "aws_iam_policy" "least_privilege" {
  name = "least-privilege-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-bucket",
          "arn:aws:s3:::my-bucket/*"
        ]
      }
    ]
  })
}

# ============================================================================
# SECURITY ISSUE 10: VPC WITHOUT FLOW LOGS (MEDIUM SEVERITY)
# ============================================================================

# ✗ BAD: VPC without flow logs - tfsec will flag as aws-vpc-enable-flow-logs
resource "aws_vpc" "no_flow_logs" {
  cidr_block = "10.0.0.0/16"
  # Missing flow logs configuration
}

# ✓ GOOD: VPC with flow logs enabled
resource "aws_vpc" "with_flow_logs" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_flow_log" "with_flow_logs" {
  iam_role_arn = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type = "ALL"
  vpc_id = aws_vpc.with_flow_logs.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name = "/aws/vpc/flow-logs"
  retention_in_days = 30
}

resource "aws_iam_role" "flow_logs" {
  name = "vpc-flow-logs-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_logs" {
  name = "vpc-flow-logs-policy"
  role = aws_iam_role.flow_logs.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# TFSEC CONFIGURATION FILE (.tfsec/config.yml)
# ============================================================================

# Location: .tfsec/config.yml
# Content:
#
# minimal_severity: WARNING
# rules:
#   - aws-s3-enable-bucket-encryption
#   - aws-s3-block-public-access
#   - aws-rds-encrypt-instance-storage
#   - aws-vpc-add-ingress-rule
# skip_checks:
#   - AVD-AWS-0001  # Skip specific checks if false positive
# custom_checks:
#   - name: Custom Check
#     description: Custom security rule
#     impact: MEDIUM
#     resolution: Fix this
#     code: 'resource.aws_s3_bucket.*.server_side_encryption_configuration exists'

# ============================================================================
# TFSEC GITHUB ACTION INTEGRATION
# ============================================================================

# Location: .github/workflows/tfsec.yml
# Content:
#
# name: tfsec scan
# on:
#   pull_request:
#   push:
#     branches:
#       - main
#
# jobs:
#   tfsec:
#     runs-on: ubuntu-latest
#     steps:
#       - uses: actions/checkout@v3
#       - uses: aquasecurity/tfsec-action@latest
#         with:
#           working_directory: '.'
#           version: latest
#           format: 'sarif'
#           output_file: results.sarif
#       - uses: github/codeql-action/upload-sarif@v2
#         with:
#           sarif_file: results.sarif

# ============================================================================
# RUNNING TFSEC LOCALLY
# ============================================================================

# Installation:
# brew install tfsec (macOS)
# choco install tfsec (Windows)
# Or download: https://github.com/aquasecurity/tfsec/releases

# Basic scan:
# tfsec .

# Scan with output formats:
# tfsec . -f json > results.json
# tfsec . -f sarif > results.sarif
# tfsec . -f csv > results.csv
# tfsec . -f junit > results.xml

# Scan with severity filtering:
# tfsec . --minimum-severity HIGH
# tfsec . --minimum-severity CRITICAL

# Scan specific directory:
# tfsec ./terraform

# Skip checks:
# tfsec . --skip aws-s3-enable-bucket-encryption

# Run with config file:
# tfsec . --config-file .tfsec/config.yml

# Generate SARIF output (for GitHub):
# tfsec . --format sarif --output results.sarif

# ============================================================================
# COMMON TFSEC CHECKS
# ============================================================================

# HIGH SEVERITY:
# - aws-s3-enable-bucket-encryption
# - aws-s3-block-public-access
# - aws-rds-encrypt-instance-storage
# - aws-vpc-add-ingress-rule (overly permissive)
# - aws-iam-no-wildcard-actions
# - aws-rds-no-public-db
# - aws-ebs-encryption-by-default
# - aws-security-group-with-port (SSH 22, RDP 3389 open)

# MEDIUM SEVERITY:
# - aws-s3-enable-versioning
# - aws-vpc-enable-flow-logs
# - aws-cloudtrail-enable-logging
# - aws-kms-enable-key-rotation
# - aws-ec2-security-group-without-prefix

# NOTES:
# - Always run tfsec before committing
# - Integrate into CI/CD pipeline
# - Review each finding carefully (not all are blocker)
# - Document exceptions with comments
# - Keep tfsec and rules updated

# ============================================================================
