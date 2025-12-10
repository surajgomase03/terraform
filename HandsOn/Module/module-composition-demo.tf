# Module Composition Demo
# Demonstrates composing multiple modules to build complete applications

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
# MODULE COMPOSITION STRATEGY
# ============================================================================

# Composition: Building complete infrastructure by combining modules
# 
# Architecture:
# 
#     root module (this file)
#         ├── vpc module
#         ├── security module
#         ├── compute module
#         ├── database module
#         ├── storage module
#         └── monitoring module
#
# Data flows: root → modules, modules → root (via outputs)

# ============================================================================
# INPUT VARIABLES (Root module level)
# ============================================================================

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Must be dev, staging, or prod."
  }
}

variable "instance_count" {
  description = "Number of application instances"
  type        = number
  default     = 3
}

variable "enable_monitoring" {
  description = "Enable CloudWatch monitoring"
  type        = bool
  default     = true
}

variable "enable_backups" {
  description = "Enable automated backups"
  type        = bool
  default     = true
}

# ============================================================================
# LOCAL VALUES (Computed at root level)
# ============================================================================

locals {
  resource_prefix = "${var.app_name}-${var.environment}"
  
  common_tags = {
    Application = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    CreatedDate = timestamp()
  }

  # Configuration selection based on environment
  instance_config = {
    dev = {
      instance_type = "t2.micro"
      db_instance_class = "db.t2.micro"
      enable_multi_az = false
    }
    staging = {
      instance_type = "t3.small"
      db_instance_class = "db.t3.small"
      enable_multi_az = false
    }
    prod = {
      instance_type = "t3.medium"
      db_instance_class = "db.r5.large"
      enable_multi_az = true
    }
  }

  selected_config = local.instance_config[var.environment]
}

# ============================================================================
# MODULE 1: VPC (Networking Foundation)
# ============================================================================

module "vpc" {
  source = "./modules/vpc"

  name           = local.resource_prefix
  cidr           = "10.0.0.0/16"
  azs            = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = (var.environment == "prod")
  single_nat_gateway = (var.environment != "prod")
  
  tags = local.common_tags
}

# ============================================================================
# MODULE 2: SECURITY GROUPS
# ============================================================================

module "security" {
  source = "./modules/security"

  vpc_id           = module.vpc.vpc_id
  app_name         = var.app_name
  environment      = var.environment
  instance_cidr    = module.vpc.private_subnets_cidr_blocks
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# ============================================================================
# MODULE 3: DATABASE (Data Storage)
# ============================================================================

module "database" {
  source = "./modules/database"

  identifier        = local.resource_prefix
  engine            = "postgres"
  instance_class    = local.selected_config.db_instance_class
  allocated_storage = var.environment == "prod" ? 100 : 20
  
  db_name  = "appdb"
  username = "dbadmin"
  
  multi_az    = local.selected_config.enable_multi_az
  backup_retention = var.enable_backups ? 30 : 1
  
  subnet_ids          = module.vpc.database_subnet_ids
  security_group_ids  = [module.security.database_security_group_id]
  
  tags = local.common_tags
  
  depends_on = [module.vpc, module.security]
}

# ============================================================================
# MODULE 4: STORAGE (S3, EBS, etc.)
# ============================================================================

module "storage" {
  source = "./modules/storage"

  bucket_name     = "${local.resource_prefix}-data"
  enable_versioning = var.enable_backups
  enable_encryption = true
  
  log_retention_days = var.environment == "prod" ? 365 : 30
  
  tags = local.common_tags
  
  depends_on = [module.vpc]
}

# ============================================================================
# MODULE 5: COMPUTE (EC2, ALB, ASG)
# ============================================================================

module "compute" {
  source = "./modules/compute"

  name              = local.resource_prefix
  instance_count    = var.instance_count
  instance_type     = local.selected_config.instance_type
  
  vpc_id                = module.vpc.vpc_id
  subnet_ids            = module.vpc.private_subnets
  security_group_ids    = [module.security.app_security_group_id]
  
  # Compose with database module outputs
  db_endpoint      = module.database.endpoint
  db_port          = module.database.port
  
  # Compose with storage module outputs
  s3_bucket        = module.storage.bucket_name
  
  # Optional features
  enable_monitoring     = var.enable_monitoring
  cloudwatch_sg_id      = module.security.monitoring_security_group_id
  
  tags = local.common_tags
  
  depends_on = [
    module.database,
    module.storage,
    module.security
  ]
}

# ============================================================================
# MODULE 6: MONITORING (CloudWatch, Alarms)
# ============================================================================

module "monitoring" {
  source = "./modules/monitoring"

  app_name    = var.app_name
  environment = var.environment
  
  # Monitor compute resources
  instance_ids    = module.compute.instance_ids
  alb_arn         = module.compute.alb_arn
  target_group_arn = module.compute.target_group_arn
  
  # Monitor database
  db_instance_id  = module.database.instance_id
  
  # Alert configuration
  alarm_email = "ops@company.com"
  enable_dashboards = (var.environment == "prod")
  
  tags = local.common_tags
  
  depends_on = [
    module.compute,
    module.database
  ]
}

# ============================================================================
# DATA SOURCES (Used by root and/or modules)
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# OUTPUTS (From composed modules)
# ============================================================================

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "vpc_cidr" {
  description = "VPC CIDR block"
  value       = module.vpc.vpc_cidr
}

# Compute Outputs
output "alb_dns_name" {
  description = "ALB DNS name for accessing application"
  value       = module.compute.alb_dns_name
  sensitive   = false
}

output "instance_ids" {
  description = "Application instance IDs"
  value       = module.compute.instance_ids
}

# Database Outputs
output "database_endpoint" {
  description = "RDS database endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "database_name" {
  description = "Database name"
  value       = module.database.db_name
}

# Storage Outputs
output "s3_bucket_name" {
  description = "S3 bucket for application data"
  value       = module.storage.bucket_name
}

# Monitoring Outputs
output "monitoring_dashboard_url" {
  description = "CloudWatch dashboard URL"
  value       = module.monitoring.dashboard_url
}

# Composite Output (Everything needed to access the app)
output "application_access" {
  description = "Complete application access information"
  value = {
    load_balancer_url = "http://${module.compute.alb_dns_name}"
    database_endpoint = module.database.endpoint
    s3_bucket         = module.storage.bucket_name
    monitoring_dashboard = module.monitoring.dashboard_url
  }
  sensitive = false
}

# ============================================================================
# MODULE COMPOSITION PATTERNS
# ============================================================================

# Pattern 1: LAYERED COMPOSITION
# Layer 1 (Foundation): VPC, Subnets, IGW
# Layer 2 (Security):   Security Groups, NACLs
# Layer 3 (Compute):    EC2, ALB, ASG
# Layer 4 (Data):       RDS, S3, DynamoDB
# Layer 5 (Monitoring): CloudWatch, Alarms

# Pattern 2: FEATURE-BASED COMPOSITION
# Each module represents a feature:
# - Web module: ALB + EC2 + ASG
# - Cache module: ElastiCache + Security Group
# - Queue module: SQS + SNS
# - Database module: RDS + Backup

# Pattern 3: ENVIRONMENT-SPECIFIC COMPOSITION
# Base modules (same for all environments):
#   - vpc, security, monitoring
# Scaled modules (different for each environment):
#   - compute (1 instance vs 5)
#   - database (t2.micro vs r5.large)
#   - storage (20GB vs 500GB)

# ============================================================================
# MODULE COMPOSITION BEST PRACTICES
# ============================================================================

# 1. DEPENDENCY ORDER
#    - VPC first (foundation)
#    - Security groups next (needed by others)
#    - Compute and database together (can be parallel)
#    - Monitoring last (observes everything)

# 2. USE EXPLICIT DEPENDENCIES
#    depends_on = [module.vpc, module.security]
#    (Terraform infers from resource references, but explicit is clear)

# 3. PASS OUTPUTS AS INPUTS
#    Don't hard-code values
#    ✓ security_group_id = module.security.sg_id
#    ✗ security_group_id = "sg-12345"

# 4. COMPOSITION AT ROOT LEVEL
#    Root module orchestrates sub-modules
#    Sub-modules don't call other modules (usually)
#    Exception: When building composite modules for reuse

# 5. CONSISTENT TAGGING
#    Pass common_tags to all modules
#    Merge with module-specific tags
#    Enables cost allocation and resource tracking

# 6. ENVIRONMENT-SPECIFIC CONFIGURATION
#    Use locals and conditionals
#    Don't duplicate modules per environment
#    Example: instance_type = local.selected_config[var.environment].type

# 7. MODULAR OUTPUTS
#    Export essential information
#    Root aggregates outputs from all modules
#    Hide internal details (internal IDs, etc.)

# 8. TESTING COMPOSITION
#    Test individual modules
#    Test module interactions
#    Test in multiple environments
#    Document expected outputs

# ============================================================================
