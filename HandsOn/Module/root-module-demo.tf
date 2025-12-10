# Root Module Demo
# Demonstrates the root module structure and best practices

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "prod"
      ManagedBy   = "Terraform"
      Project     = "MyApp"
    }
  }
}

# ============================================================================
# ROOT MODULE STRUCTURE
# ============================================================================
# A root module is any Terraform configuration that has:
# - terraform {} block
# - provider {} blocks
# - resource {} blocks (or calls to child modules)
# - variables.tf (input variables)
# - outputs.tf (output values)
# - main.tf (main resources)
# - terraform.tfvars (variable values)

# ============================================================================
# SECTION 1: INPUT VARIABLES
# ============================================================================

variable "app_name" {
  description = "Application name"
  type        = string
  default     = "myapp"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Owner = "DevOps"
  }
}

# ============================================================================
# SECTION 2: LOCAL VALUES
# ============================================================================

locals {
  # Computed values used throughout root module
  resource_prefix = "${var.app_name}-${var.environment}"
  
  common_tags = merge(
    var.tags,
    {
      Name        = local.resource_prefix
      Environment = var.environment
      CreatedDate = timestamp()
    }
  )

  # Data source references
  vpc_cidr = "10.0.0.0/16"
}

# ============================================================================
# SECTION 3: CALLING CHILD MODULES
# ============================================================================

module "vpc" {
  source = "./modules/vpc"

  # Pass variables to child module
  vpc_name       = local.resource_prefix
  cidr_block     = local.vpc_cidr
  enable_dns     = true
  tags           = local.common_tags

  # Explicit dependency (if needed)
  depends_on = []
}

module "security" {
  source = "./modules/security"

  vpc_id          = module.vpc.vpc_id
  app_name        = var.app_name
  environment     = var.environment
  tags            = local.common_tags
}

module "compute" {
  source = "./modules/compute"

  instance_count      = var.instance_count
  instance_name       = local.resource_prefix
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.subnet_ids
  security_group_ids  = [module.security.app_security_group_id]
  tags                = local.common_tags

  depends_on = [module.security]
}

# ============================================================================
# SECTION 4: DATA SOURCES (in root module)
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "latest_ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

# ============================================================================
# SECTION 5: OUTPUTS (from root module)
# ============================================================================

output "vpc_id" {
  description = "VPC ID for reference by other modules"
  value       = module.vpc.vpc_id
}

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = module.compute.instance_ids
}

output "security_group_id" {
  description = "Application security group ID"
  value       = module.security.app_security_group_id
}

output "environment_info" {
  description = "Environment information"
  value = {
    app_name    = var.app_name
    environment = var.environment
    region      = data.aws_availability_zones.available.names
  }
}

# ============================================================================
# ROOT MODULE BEST PRACTICES
# ============================================================================

# 1. Clear separation of concerns
#    - variables.tf: Input variables and validation
#    - main.tf: Resource and module definitions
#    - outputs.tf: Output values
#    - locals.tf: Local values (optional)

# 2. Use locals for computed values
#    - Reduces repetition
#    - Easier to change naming conventions
#    - Single source of truth

# 3. Always use module sources with relative paths
#    - ./modules/vpc (local module)
#    - ../modules/networking (parent directory)
#    - NOT absolute paths (breaks portability)

# 4. Pass variables explicitly
#    - Each module call documents required inputs
#    - Easier to understand data flow
#    - Easier to test and maintain

# 5. Use explicit depends_on sparingly
#    - Prefer implicit dependencies (resource references)
#    - Use depends_on only for side effects

# 6. Organize modules logically
#    - Group related resources (vpc, security, compute)
#    - Each module has single responsibility
#    - Promotes reusability

# 7. Tag everything consistently
#    - Use locals for common tags
#    - Apply to all resources
#    - Helps with cost allocation and management

# 8. Version all providers
#    - Prevents breaking changes
#    - Documents compatibility
#    - Easier to upgrade deliberately

# 9. Document root module inputs
#    - Clear descriptions for all variables
#    - Add validation rules
#    - Specify defaults

# 10. Export important outputs
#     - Instance IDs, VPC IDs, etc.
#     - Use terraform_remote_state to share with other projects
#     - Document output purposes

# ============================================================================
