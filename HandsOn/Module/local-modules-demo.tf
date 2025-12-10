# Local Modules Demo
# Demonstrates local module structures and organization

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
# LOCAL MODULE STRUCTURE (PROJECT LAYOUT)
# ============================================================================

# Typical project structure with local modules:
#
# project-root/
# ├── main.tf
# ├── variables.tf
# ├── outputs.tf
# ├── terraform.tfvars
# ├── modules/
# │   ├── vpc/
# │   │   ├── main.tf
# │   │   ├── variables.tf
# │   │   ├── outputs.tf
# │   │   └── README.md
# │   ├── compute/
# │   │   ├── main.tf
# │   │   ├── variables.tf
# │   │   ├── outputs.tf
# │   │   └── README.md
# │   └── database/
# │       ├── main.tf
# │       ├── variables.tf
# │       ├── outputs.tf
# │       └── README.md
# ├── environments/
# │   ├── dev/
# │   │   ├── main.tf
# │   │   └── terraform.tfvars
# │   ├── staging/
# │   │   ├── main.tf
# │   │   └── terraform.tfvars
# │   └── prod/
# │       ├── main.tf
# │       └── terraform.tfvars
# └── .gitignore

# ============================================================================
# EXAMPLE 1: CALLING LOCAL MODULES
# ============================================================================

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 2
}

# Reference local module with relative path
module "vpc_local" {
  source = "./modules/vpc"

  vpc_name       = "app-vpc"
  cidr_block     = "10.0.0.0/16"
  enable_dns     = true
  tags = {
    Environment = var.environment
  }
}

module "database_local" {
  source = "./modules/database"

  db_name         = "appdb"
  engine          = "postgres"
  instance_class  = "db.t3.micro"
  allocated_storage = 20
  vpc_id          = module.vpc_local.vpc_id
  subnet_ids      = module.vpc_local.subnet_ids
  
  tags = {
    Environment = var.environment
  }
}

module "compute_local" {
  source = "./modules/compute"

  instance_count    = var.instance_count
  instance_name     = "app"
  vpc_id            = module.vpc_local.vpc_id
  subnet_ids        = module.vpc_local.subnet_ids
  db_endpoint       = module.database_local.db_endpoint
  
  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# EXAMPLE 2: NESTED MODULES (MODULES CALLING MODULES)
# ============================================================================

# file: modules/networking/main.tf
# This module calls other modules (VPC, Security Groups, etc.)

module "networking" {
  source = "./modules/networking"  # This module is composed of sub-modules

  vpc_name       = "app-vpc"
  cidr_block     = "10.0.0.0/16"
  enable_nat     = true
  enable_vpn     = false
  
  tags = {
    Environment = var.environment
  }
}

# ============================================================================
# EXAMPLE 3: MODULE COMPOSITION (COMBINING MULTIPLE MODULES)
# ============================================================================

# Strategy 1: Flat module structure (modules at same level)
module "module_a" {
  source = "./modules/a"
  name   = "a"
}

module "module_b" {
  source = "./modules/b"
  name   = "b"
  depends_on = [module.module_a]
}

# Strategy 2: Hierarchical module structure (modules nested)
module "parent" {
  source = "./modules/parent"  # This has sub-modules internally
  name   = "parent"
}

# ============================================================================
# EXAMPLE 4: LOCAL MODULE CONTENT (FILE CONTENTS)
# ============================================================================

# FILE: modules/vpc/variables.tf
# (Shows input variables for VPC module)

# variable "vpc_name" { type = string }
# variable "cidr_block" { type = string }
# variable "enable_dns" { type = bool }
# variable "tags" { type = map(string) }

# FILE: modules/vpc/main.tf
# (Shows resources created by VPC module)

# resource "aws_vpc" "main" {
#   cidr_block           = var.cidr_block
#   enable_dns_hostnames = var.enable_dns
#   tags                 = var.tags
# }

# resource "aws_subnet" "main" {
#   for_each   = toset(...)
#   vpc_id     = aws_vpc.main.id
#   cidr_block = each.value
# }

# FILE: modules/vpc/outputs.tf
# (Shows outputs from VPC module)

# output "vpc_id" { value = aws_vpc.main.id }
# output "subnet_ids" { value = aws_subnet.main[*].id }

# ============================================================================
# EXAMPLE 5: ENVIRONMENT-SPECIFIC CONFIGURATION
# ============================================================================

# file: environments/prod/main.tf

# terraform {
#   backend "s3" {
#     bucket = "my-terraform-state"
#     key    = "prod/terraform.tfstate"
#     region = "us-east-1"
#   }
# }

# module "app_prod" {
#   source = "../../modules/app"
#   
#   environment       = "prod"
#   instance_count    = 5
#   instance_type     = "t3.large"
#   database_size     = "db.r5.xlarge"
#   enable_monitoring = true
#   
#   providers = {
#     aws = aws.prod
#   }
# }

# file: environments/prod/terraform.tfvars
# environment       = "prod"
# instance_count    = 5
# instance_type     = "t3.large"
# enable_monitoring = true

# file: environments/dev/main.tf
# (Same structure as prod, but different variables)

# file: environments/dev/terraform.tfvars
# environment       = "dev"
# instance_count    = 1
# instance_type     = "t2.micro"
# enable_monitoring = false

# ============================================================================
# EXAMPLE 6: SHARED MODULES VS ENVIRONMENT-SPECIFIC
# ============================================================================

# Shared modules (used by all environments):
# modules/
# ├── vpc/              # All environments use
# ├── security/         # All environments use
# ├── monitoring/       # All environments use
# └── logging/          # All environments use

# Environment-specific modules:
# modules/
# ├── dev/              # Dev-only optimizations
# │   └── testing/
# ├── prod/             # Prod-specific requirements
# │   ├── ha/           # High availability
# │   ├── disaster-recovery/
# │   └── compliance/

# ============================================================================
# EXAMPLE 7: MODULE REUSABILITY PATTERNS
# ============================================================================

# Pattern 1: Single-purpose modules
# modules/redis/ - only creates Redis cluster
# modules/postgres/ - only creates RDS instance
# modules/eks/ - only creates EKS cluster

# Pattern 2: Multi-purpose modules
# modules/database/ - can create any DB (RDS, DynamoDB, etc.)
# modules/storage/ - can create any storage (S3, EBS, etc.)

# Pattern 3: Composite modules
# modules/web-app/ - creates entire web app stack
#   ├── Calls vpc module
#   ├── Calls compute module
#   ├── Calls database module
#   └── Calls monitoring module

# ============================================================================
# LOCAL MODULES BEST PRACTICES
# ============================================================================

# 1. USE CONSISTENT NAMING
#    - module naming: snake_case
#    - resource names: descriptive, not generic
#    - Example: module "app_vpc" (not vpc1, vpc_a, etc.)

# 2. ORGANIZE BY FUNCTION
#    - modules/vpc/ - networking
#    - modules/compute/ - servers
#    - modules/database/ - data storage
#    - modules/monitoring/ - observability

# 3. SINGLE RESPONSIBILITY PRINCIPLE
#    - Each module does one thing well
#    - Easy to test independently
#    - Easy to reuse in other projects

# 4. CLEAR DOCUMENTATION
#    - README.md in each module
#    - Document inputs and outputs
#    - Provide usage examples
#    - Show expected outputs

# 5. VERSION LOCAL MODULES
#    - Don't use version constraint for local
#    - source = "./modules/vpc" (not with version)
#    - Version via git tags if shared across projects

# 6. ENVIRONMENT-SPECIFIC VALUES
#    - Use terraform.tfvars per environment
#    - Don't hard-code environment in code
#    - Override in environments/ directory

# 7. PASS DEPENDENCIES EXPLICITLY
#    - Don't rely on implicit dependencies
#    - Use module outputs as inputs
#    - Use depends_on for non-implicit deps

# 8. TEST MODULES INDEPENDENTLY
#    - Create test directory
#    - Test module with minimal dependencies
#    - Verify inputs and outputs

# ============================================================================
