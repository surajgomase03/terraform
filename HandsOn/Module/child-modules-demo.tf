# Child Modules Demo
# Demonstrates child module structure, inputs, outputs, and reusability

# ============================================================================
# FILE: modules/vpc/main.tf
# ============================================================================

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# ============================================================================
# SECTION 1: CHILD MODULE INPUTS (INPUT VARIABLES)
# ============================================================================

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "Must be valid CIDR block."
  }
}

variable "enable_dns" {
  description = "Enable DNS hostnames"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# ============================================================================
# SECTION 2: LOCAL VALUES (INTERNAL LOGIC)
# ============================================================================

locals {
  # Compute values used within this module
  subnet_count = 3
  
  # Derived from inputs
  subnet_cidrs = [
    cidrsubnet(var.cidr_block, 2, 0),  # 10.0.0.0/18
    cidrsubnet(var.cidr_block, 2, 1),  # 10.0.64.0/18
    cidrsubnet(var.cidr_block, 2, 2),  # 10.0.128.0/18
  ]

  common_tags = merge(
    var.tags,
    {
      Module = "VPC"
    }
  )
}

# ============================================================================
# SECTION 3: RESOURCES (MODULE IMPLEMENTATION)
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = var.enable_dns
  enable_dns_support   = var.enable_dns

  tags = merge(
    local.common_tags,
    {
      Name = var.vpc_name
    }
  )
}

resource "aws_subnet" "main" {
  count                   = local.subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.subnet_cidrs[count.index]
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    local.common_tags,
    {
      Name = "${var.vpc_name}-subnet-${count.index + 1}"
    }
  )
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    local.common_tags,
    {
      Name = "${var.vpc_name}-igw"
    }
  )
}

# ============================================================================
# SECTION 4: DATA SOURCES (INTERNAL TO MODULE)
# ============================================================================

data "aws_availability_zones" "available" {
  state = "available"
}

# ============================================================================
# SECTION 5: OUTPUTS (EXPOSE TO PARENT MODULE)
# ============================================================================

output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "subnet_ids" {
  description = "IDs of subnets created by this module"
  value       = aws_subnet.main[*].id
}

output "igw_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "availability_zones" {
  description = "List of AZs where subnets created"
  value       = aws_subnet.main[*].availability_zone
}

# ============================================================================
# FILE: modules/security/main.tf
# ============================================================================

variable "vpc_id" {
  description = "VPC ID for security group"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

resource "aws_security_group" "app" {
  name_prefix = "${var.app_name}-"
  description = "Security group for ${var.app_name} in ${var.environment}"
  vpc_id      = var.vpc_id

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
    var.tags,
    {
      Name   = "${var.app_name}-sg"
      Module = "Security"
    }
  )
}

output "app_security_group_id" {
  description = "Security group ID for application"
  value       = aws_security_group.app.id
}

# ============================================================================
# FILE: modules/compute/main.tf
# ============================================================================

variable "instance_count" {
  description = "Number of instances"
  type        = number
  default     = 1
}

variable "instance_name" {
  description = "Name prefix for instances"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for instances"
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_instance" "app" {
  count                    = var.instance_count
  ami                      = data.aws_ami.ubuntu.id
  instance_type            = "t2.micro"
  subnet_id                = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids   = var.security_group_ids

  tags = merge(
    var.tags,
    {
      Name   = "${var.instance_name}-${count.index + 1}"
      Module = "Compute"
    }
  )
}

output "instance_ids" {
  description = "IDs of created instances"
  value       = aws_instance.app[*].id
}

output "instance_private_ips" {
  description = "Private IPs of instances"
  value       = aws_instance.app[*].private_ip
}

# ============================================================================
# CHILD MODULE BEST PRACTICES
# ============================================================================

# 1. SINGLE RESPONSIBILITY
#    Each module focuses on one thing:
#    - vpc module creates VPC infrastructure
#    - security module creates security groups
#    - compute module creates compute resources

# 2. CLEAR INPUTS/OUTPUTS
#    - Document all input variables
#    - Export only necessary outputs
#    - Hide internal implementation details

# 3. SENSIBLE DEFAULTS
#    - Provide defaults for common values
#    - Allow customization via variables
#    - Reduces boilerplate in parent

# 4. INTERNAL LOCALS
#    - Use locals for derived values
#    - Keep locals internal to module
#    - Don't expose in outputs

# 5. CONSISTENT TAGGING
#    - Accept tags as input variable
#    - Merge with module-specific tags
#    - Apply to all resources

# 6. NO HARD-CODED VALUES
#    - Everything should be variable
#    - Single source of truth for configuration
#    - Easy to override and test

# 7. VALIDATION AND ERROR MESSAGES
#    - Add validation to important variables
#    - Clear error messages
#    - Fail fast on invalid input

# 8. PROVIDER REQUIREMENTS
#    - Specify required_providers
#    - Version constraints
#    - Inheritance from parent is not reliable

# ============================================================================
