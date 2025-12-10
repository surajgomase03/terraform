# state-lock-demo.tf
# Demonstrates configuring a backend that supports state locking (S3 + DynamoDB example)

terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "example/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
  }
}

# Notes:
# - Create the S3 bucket and DynamoDB table first (outside of this config) or use a separate bootstrap process.
# - DynamoDB table must use string primary key named 'LockID' for locking.

# Interview demo steps:
# 1) Configure backend and run `terraform init`.
# 2) Run `terraform plan` from two shells to observe locking behavior when applying.
