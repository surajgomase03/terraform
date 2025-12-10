# Remote State Configuration Demo
# Demonstrates storing state in remote backends (S3 with DynamoDB locking)

terraform {
  required_version = ">= 1.0"

  # S3 backend (most common for AWS)
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }

  # Alternative: Terraform Cloud backend
  # cloud {
  #   organization = "my-org"
  #   workspaces {
  #     name = "production"
  #   }
  # }

  # Alternative: Azure Storage backend
  # backend "azurerm" {
  #   resource_group_name  = "my-rg"
  #   storage_account_name = "mysa"
  #   container_name       = "tfstate"
  #   key                  = "prod.tfstate"
  # }
}

# Provider configuration
provider "aws" {
  region = "us-east-1"
}

# Example: Simple security group (state will be stored remotely)
resource "aws_security_group" "remote_state_example" {
  name_prefix = "remote-state-"
  description = "Example resource with remote state tracking"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "remote-state-example"
  }
}

# Output the security group ID (useful for cross-project references via remote state)
output "security_group_id" {
  value       = aws_security_group.remote_state_example.id
  description = "Security group ID stored in remote state"
}

# Example: Reference remote state from another workspace
# data "terraform_remote_state" "prod" {
#   backend = "s3"
#   config = {
#     bucket = "my-terraform-state"
#     key    = "prod/terraform.tfstate"
#     region = "us-east-1"
#   }
# }

# Use remote output in current module
# resource "aws_instance" "app" {
#   security_groups = [data.terraform_remote_state.prod.outputs.security_group_id]
# }
