# State Locking Demo
# Demonstrates concurrent access prevention and state lock configuration

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    # DynamoDB table required for state locking with S3 backend
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Example 1: DynamoDB table for state locking (create this first)
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "Terraform State Lock Table"
    Environment = "prod"
  }
}

# Example 2: Resource that demonstrates lock behavior
resource "null_resource" "state_lock_demo" {
  triggers = {
    message = "This resource's operations are protected by state locking"
  }
}

# Example 3: Multiple resources to show concurrent lock protection
resource "null_resource" "locked_resource_1" {
  triggers = {
    name = "resource-1"
  }
}

resource "null_resource" "locked_resource_2" {
  triggers = {
    name = "resource-2"
  }

  depends_on = [null_resource.locked_resource_1]
}

# State lock information output
output "dynamodb_lock_table" {
  value       = aws_dynamodb_table.terraform_locks.name
  description = "DynamoDB table used for state locking"
}

output "lock_mechanism" {
  value       = "When terraform apply runs, it writes a lock entry to DynamoDB. Other applies wait or fail."
  description = "How state locking prevents concurrent modifications"
}

# Best practices for state locking:
# 1. Use DynamoDB for S3 backend state locking
# 2. Create DynamoDB table with LockID as hash key (string type)
# 3. Set billing mode to PAY_PER_REQUEST for cost efficiency
# 4. Enable encryption on S3 bucket
# 5. For Terraform Cloud, locking is automatic (no setup needed)
# 6. Use `-lock=false` flag cautiously (only for read-only operations)

# Manual lock operations (terraform CLI):
# terraform apply -lock=false          # Disable lock (not recommended)
# terraform apply -lock=true           # Explicit lock (default)
# terraform apply -lock-timeout=5m     # Wait 5 minutes for lock
# terraform force-unlock <LOCK_ID>     # Manual unlock (use only if locked forever)
