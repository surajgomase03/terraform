# Terraform CI/CD Demo
# Demonstrates CI/CD patterns for automated Terraform deployments

# This file shows how to structure Terraform code for CI/CD pipelines
# It includes patterns for plan approval, automated apply, and state management

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
  region = var.aws_region
}

# ============================================================================
# ENVIRONMENT-SPECIFIC VARIABLES
# ============================================================================

# These variables allow different environments (dev, staging, prod) to have
# different configurations using the same Terraform code

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "instance_count" {
  description = "Number of EC2 instances (env-dependent)"
  type        = number
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "EC2 instance type (env-dependent)"
  type        = string
  default     = "t3.micro"
}

variable "enable_monitoring" {
  description = "Enable detailed monitoring (prod always enabled)"
  type        = bool
  default     = false
}

variable "backup_retention_days" {
  description = "Database backup retention (env-dependent)"
  type        = number
  default     = 7
  validation {
    condition     = var.backup_retention_days >= 7 && var.backup_retention_days <= 35
    error_message = "Backup retention must be 7-35 days."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# LOCAL VALUES FOR CI/CD CONFIGURATION
# ============================================================================

locals {
  # Common tags applied to all resources
  common_tags = merge(
    var.tags,
    {
      Environment = var.environment
      ManagedBy   = "Terraform"
      Application = var.app_name
      CreatedDate = timestamp()
    }
  )

  # Environment-specific configuration
  env_config = {
    dev = {
      instance_count = 1
      instance_type  = "t3.micro"
      monitoring     = false
      backup_days    = 7
    }
    staging = {
      instance_count = 2
      instance_type  = "t3.small"
      monitoring     = true
      backup_days    = 14
    }
    prod = {
      instance_count = 3
      instance_type  = "t3.medium"
      monitoring     = true
      backup_days    = 30
    }
  }

  # Use environment-specific or variable values
  effective_instance_count = coalesce(
    var.instance_count != 1 ? var.instance_count : null,
    local.env_config[var.environment].instance_count
  )

  effective_instance_type = coalesce(
    var.instance_type != "t3.micro" ? var.instance_type : null,
    local.env_config[var.environment].instance_type
  )

  effective_monitoring = var.environment == "prod" ? true : var.enable_monitoring

  effective_backup_days = var.environment == "prod" ? 30 : var.backup_retention_days
}

# ============================================================================
# VPC FOR ISOLATED ENVIRONMENT
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-vpc"
    }
  )
}

resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-public-subnet-${count.index + 1}"
    }
  )
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 101}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-private-subnet-${count.index + 1}"
    }
  )
}

# ============================================================================
# EC2 INSTANCES (AUTO-SCALED WITH ENVIRONMENT)
# ============================================================================

resource "aws_security_group" "app" {
  name        = "${var.app_name}-app-sg"
  description = "Security group for ${var.app_name} application"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-app-sg"
    }
  )
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "app" {
  count           = local.effective_instance_count
  ami             = data.aws_ami.ubuntu.id
  instance_type   = local.effective_instance_type
  subnet_id       = aws_subnet.public[count.index % length(aws_subnet.public)].id
  security_groups = [aws_security_group.app.id]

  # Enable monitoring for prod
  monitoring = local.effective_monitoring

  # Simple user data script
  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Environment: ${var.environment}" > /var/www/html/index.html
              EOF
  )

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-instance-${count.index + 1}"
    }
  )

  depends_on = [aws_security_group.app]
}

# ============================================================================
# DATABASE (ENVIRONMENT-SPECIFIC CONFIGURATION)
# ============================================================================

resource "aws_security_group" "database" {
  name        = "${var.app_name}-db-sg"
  description = "Security group for ${var.app_name} database"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-db-sg"
    }
  )
}

resource "aws_db_subnet_group" "main" {
  name       = "${var.app_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-db-subnet-group"
    }
  )
}

resource "aws_db_instance" "main" {
  identifier     = "${var.app_name}-db-${var.environment}"
  engine         = "postgres"
  engine_version = "15.2"
  
  # Environment-specific sizing
  instance_class    = var.environment == "prod" ? "db.t3.medium" : "db.t3.micro"
  allocated_storage = var.environment == "prod" ? 100 : 20

  # Security
  storage_encrypted = true
  db_name           = replace("${var.app_name}db", "-", "_")
  username          = "postgres"
  password          = random_password.db_password.result

  # Backup configuration (env-dependent)
  backup_retention_period = local.effective_backup_days
  backup_window           = "03:00-04:00"
  
  # High availability for prod
  multi_az = var.environment == "prod" ? true : false

  # Backup/restore
  skip_final_snapshot       = var.environment == "dev" ? true : false
  final_snapshot_identifier = var.environment != "dev" ? "${var.app_name}-db-${var.environment}-final-${timestamp()}" : null

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]

  # Monitoring (prod only)
  enabled_cloudwatch_logs_exports = var.environment == "prod" ? ["postgresql"] : []
  monitoring_interval             = var.environment == "prod" ? 60 : 0
  monitoring_role_arn             = var.environment == "prod" ? aws_iam_role.rds_monitoring[0].arn : null

  tags = merge(
    local.common_tags,
    {
      Name = "${var.app_name}-db"
    }
  )

  depends_on = [aws_security_group.database]

  lifecycle {
    # Prevent accidental deletion in prod
    prevent_destroy = var.environment == "prod"
  }
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Optional RDS monitoring role for prod
resource "aws_iam_role" "rds_monitoring" {
  count = var.environment == "prod" ? 1 : 0
  name  = "${var.app_name}-rds-monitoring"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "monitoring.rds.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count      = var.environment == "prod" ? 1 : 0
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# ============================================================================
# OUTPUTS FOR CI/CD CONSUMPTION
# ============================================================================

output "environment" {
  value       = var.environment
  description = "Environment name"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "instance_ids" {
  value       = aws_instance.app[*].id
  description = "EC2 instance IDs"
}

output "instance_count" {
  value       = length(aws_instance.app)
  description = "Number of instances deployed"
}

output "database_endpoint" {
  value       = aws_db_instance.main.endpoint
  description = "RDS database endpoint"
  sensitive   = true
}

output "database_name" {
  value       = aws_db_instance.main.db_name
  description = "Database name"
}

output "security_group_id" {
  value       = aws_security_group.app.id
  description = "Application security group ID"
}

output "deployment_timestamp" {
  value       = timestamp()
  description = "Deployment timestamp"
}

output "account_id" {
  value       = data.aws_caller_identity.current.account_id
  description = "AWS account ID"
}

# ============================================================================
# TERRAFORM BACKEND CONFIGURATION
# ============================================================================

# For CI/CD, backend should be configured in backend.tf or via -backend-config
# Example backend configuration:
#
# terraform {
#   backend "s3" {
#     bucket         = "terraform-state-${AWS_ACCOUNT_ID}"
#     key            = "prod/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform-locks"
#     encrypt        = true
#   }
# }

# ============================================================================
# CI/CD INTEGRATION NOTES
# ============================================================================

# For Jenkins pipeline:
# 1. SCM checkout of Terraform code
# 2. terraform init (with -backend-config for credentials)
# 3. terraform plan (save to file)
# 4. Manual approval of plan
# 5. terraform apply (from plan file)
# 6. Export outputs for downstream jobs
#
# For GitLab pipeline:
# 1. SCM checkout automatic
# 2. terraform init in docker image
# 3. terraform plan as artifact
# 4. Manual approval via environment protection
# 5. terraform apply with approval
# 6. Artifacts and outputs stored
#
# State management:
# - Always use remote backend (S3 + DynamoDB)
# - Lock state during apply (prevents concurrent modifications)
# - Encrypt state (KMS for S3)
# - Access state only from CI/CD agents
# - Regular backups of state

# ============================================================================
