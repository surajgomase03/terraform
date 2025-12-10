# Trivy IaC Scanning Demo
# Demonstrates vulnerability scanning for Infrastructure as Code using Trivy

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
# TRIVY SCANNING BASICS
# ============================================================================

# Trivy scans Terraform code for:
# 1. Vulnerabilities (CVEs in dependencies)
# 2. Misconfigurations (security issues)
# 3. Secrets (exposed credentials)
# 4. License violations (commercial software)

# Run scans:
# trivy fs .                    # Scan filesystem (Terraform files)
# trivy image myimage:latest    # Scan Docker image
# trivy repo https://github.com/user/repo  # Scan GitHub repo
# trivy config .                # Scan configuration files

# ============================================================================
# SECURITY ISSUE 1: UNENCRYPTED S3 BUCKET
# ============================================================================

# ✗ BAD: S3 bucket without encryption
resource "aws_s3_bucket" "insecure_storage" {
  bucket = "insecure-data-bucket"
  # Missing encryption - Trivy will flag
}

resource "aws_s3_bucket_acl" "insecure_storage" {
  bucket = aws_s3_bucket.insecure_storage.id
  acl    = "private"
}

# ✓ GOOD: S3 bucket with encryption and security
resource "aws_s3_bucket" "secure_storage" {
  bucket = "secure-data-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "secure_storage" {
  bucket = aws_s3_bucket.secure_storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "secure_storage" {
  bucket = aws_s3_bucket.secure_storage.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "secure_storage" {
  bucket = aws_s3_bucket.secure_storage.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# ============================================================================
# SECURITY ISSUE 2: INSECURE RDS CONFIGURATION
# ============================================================================

# ✗ BAD: RDS with multiple security issues
resource "aws_db_instance" "insecure_db" {
  identifier            = "insecure-database"
  engine                = "mysql"
  engine_version        = "5.7"  # Outdated version
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp2"
  
  username = "admin"
  password = "SimplePassword123"  # Weak password (Trivy detects)
  
  # Missing encryption
  storage_encrypted = false
  
  # Publicly accessible (dangerous)
  publicly_accessible = true
  
  # No backup
  backup_retention_period = 0
  
  skip_final_snapshot = true
}

# ✓ GOOD: Secure RDS configuration
resource "aws_db_instance" "secure_db" {
  identifier            = "secure-database"
  engine                = "postgres"
  engine_version        = "15.2"  # Current version
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_type          = "gp3"
  
  username = "admin"
  password = random_password.db_password.result  # Randomly generated
  
  # Encryption enabled
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  
  # Private database
  publicly_accessible = false
  
  # Backup enabled
  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  
  # Multi-AZ for high availability
  multi_az = true
  
  skip_final_snapshot       = false
  final_snapshot_identifier = "secure-database-backup"
  
  # Enable monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]
  monitoring_interval             = 60
  monitoring_role_arn             = aws_iam_role.rds_monitoring.arn
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_iam_role" "rds_monitoring" {
  name = "rds-monitoring-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# SECURITY ISSUE 3: INSECURE SECURITY GROUP
# ============================================================================

# ✗ BAD: Security group open to internet
resource "aws_security_group" "insecure_web" {
  name = "insecure-web-sg"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to world (Trivy flags)
  }

  ingress {
    from_port   = 3306  # MySQL
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Database exposed (Trivy critical)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✓ GOOD: Secure security group
resource "aws_security_group" "secure_web" {
  name = "secure-web-sg"

  # Only allow HTTPS
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow HTTP redirect
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # Allow SSH from bastion only
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "secure-web-sg"
  }
}

resource "aws_security_group" "bastion" {
  name = "bastion-sg"
}

# ============================================================================
# SECURITY ISSUE 4: IAM POLICY WITH OVERLY BROAD PERMISSIONS
# ============================================================================

# ✗ BAD: IAM policy with wildcard permissions
resource "aws_iam_role" "app_insecure" {
  name = "app-role-insecure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_insecure" {
  name = "app-policy-insecure"
  role = aws_iam_role.app_insecure.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"  # Wildcard - Trivy critical finding
        Resource = "*"
      }
    ]
  })
}

# ✓ GOOD: IAM policy with least privilege
resource "aws_iam_role" "app_secure" {
  name = "app-role-secure"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_secure" {
  name = "app-policy-secure"
  role = aws_iam_role.app_secure.id

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
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ============================================================================
# SECURITY ISSUE 5: EC2 WITHOUT IMDSv2
# ============================================================================

# ✗ BAD: EC2 with IMDSv1 enabled (vulnerable)
resource "aws_instance" "insecure_instance" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # IMDSv1 is default - Trivy flags as vulnerability
  # No metadata options specified
}

# ✓ GOOD: EC2 with IMDSv2 enforced
resource "aws_instance" "secure_instance" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # Enforce IMDSv2 (prevents SSRF attacks)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"  # Enforces IMDSv2
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring = true  # Enable detailed CloudWatch monitoring

  tags = {
    Name = "secure-instance"
  }
}

# ============================================================================
# SECURITY ISSUE 6: MISSING LOGGING AND MONITORING
# ============================================================================

# ✗ BAD: No logging or monitoring
resource "aws_api_gateway_rest_api" "insecure" {
  name = "insecure-api"
}

# ✓ GOOD: API Gateway with logging enabled
resource "aws_api_gateway_rest_api" "secure" {
  name = "secure-api"
  
  depends_on = [aws_cloudwatch_log_group.api_logs]
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/secure-api"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}

resource "aws_api_gateway_stage" "secure" {
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.secure.id
  deployment_id = aws_api_gateway_deployment.secure.id

  access_log_settings {
    cloudwatch_log_group_arn = "${aws_cloudwatch_log_group.api_logs.arn}:*"
    format                   = "$context.requestId $context.identity.sourceIp $context.requestTime $context.httpMethod $context.resourcePath $context.status"
  }

  logging_level = "INFO"
  data_trace_enabled = false
  metrics_enabled    = true
}

resource "aws_api_gateway_deployment" "secure" {
  rest_api_id = aws_api_gateway_rest_api.secure.id

  depends_on = [
    aws_api_gateway_integration.secure
  ]
}

resource "aws_api_gateway_integration" "secure" {
  rest_api_id = aws_api_gateway_rest_api.secure.id
  resource_id = aws_api_gateway_rest_api.secure.root_resource_id
  http_method = "GET"
  type        = "MOCK"
}

resource "aws_kms_key" "logs" {
  description             = "KMS key for logs"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

# ============================================================================
# RUNNING TRIVY SCANS
# ============================================================================

# Installation:
# brew install trivy (macOS)
# wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
# echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
# sudo apt-get update && sudo apt-get install trivy (Linux)

# Basic filesystem scan:
# trivy fs .

# Scan with severity filter:
# trivy fs . --severity HIGH,CRITICAL

# Scan specific directory:
# trivy fs ./terraform

# Output in JSON:
# trivy fs . -f json -o results.json

# Output in SARIF (GitHub):
# trivy fs . -f sarif -o results.sarif

# Scan with custom config:
# trivy fs . --config trivy.yaml

# Show only misconfigurations:
# trivy config .

# Generate compliance report:
# trivy fs . --compliance aws

# Skip checks:
# trivy fs . --skip-dirs .terraform --skip-files *.bak

# Update vulnerability database:
# trivy image --download-db-only

# ============================================================================
# TRIVY CONFIGURATION FILE (trivy.yaml)
# ============================================================================

# severity:
#   - HIGH
#   - CRITICAL
#
# skip-dirs:
#   - .terraform
#   - .git
#   - test
#
# skip-files:
#   - "*.bak"
#   - "old_*.tf"
#
# exit-code: 1  # Non-zero exit on vulnerabilities
#
# format: sarif
# output: results.sarif
#
# db:
#   repository: ghcr.io/aquasecurity/trivy-db
#
# offline-scan: false  # Set true for airgapped environments
#
# list-all-pkgs: false  # Don't list packages without vulnerabilities

# ============================================================================
# GITHUB ACTIONS WITH TRIVY
# ============================================================================

# .github/workflows/trivy.yml:
#
# name: Trivy Scan
# on:
#   pull_request:
#   push:
#     branches:
#       - main
#
# jobs:
#   trivy:
#     runs-on: ubuntu-latest
#     steps:
#       - uses: actions/checkout@v3
#       - uses: aquasecurity/trivy-action@master
#         with:
#           scan-type: 'fs'
#           scan-ref: '.'
#           format: 'sarif'
#           output: 'trivy-results.sarif'
#       - uses: github/codeql-action/upload-sarif@v2
#         with:
#           sarif_file: 'trivy-results.sarif'

# ============================================================================
