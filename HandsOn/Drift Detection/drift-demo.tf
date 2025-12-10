# drift-demo.tf
# Demonstrates a simple resource and steps to simulate and detect drift.
# WARNING: Running this on AWS will create real resources and may incur charges.

variable "region" {
  type    = string
  default = "us-east-1"
}

provider "aws" {
  region = var.region
}

# Simple S3 bucket resource (easy to modify externally to simulate drift)
resource "aws_s3_bucket" "example" {
  bucket = "terraform-drift-demo-${random_id.bucket_id.hex}"
  acl    = "private"

  tags = {
    Name = "drift-demo-bucket"
  }
}

resource "random_id" "bucket_id" {
  byte_length = 4
}

output "bucket_name" {
  value = aws_s3_bucket.example.bucket
}

# How to simulate drift (do one of these after terraform apply):
# 1) Change a property in the cloud console, e.g., enable public access or add a tag.
#    - In S3 console, edit the bucket tag or block public access setting.
# 2) Use AWS CLI to modify the bucket (example toggling versioning):
#    aws s3api put-bucket-versioning --bucket <bucket-name> --versioning-configuration Status=Enabled
# 3) Directly edit resource in provider (console) or use another script to modify the resource.

# How to detect drift:
# - Run `terraform plan` and inspect any changes under '~' (for changed) or '-' (for destroy) or '+' (for create).
# - Run `terraform refresh` to update state from provider, then `terraform plan` to see planned changes.
# - Example commands (PowerShell):
#   terraform init
#   terraform apply -auto-approve
#   # make external change now
#   terraform plan
#   terraform refresh
#   terraform plan

# How to fix drift:
# - If the external change is desired, update your Terraform config to match and then `terraform apply`.
# - If the Terraform config is desired, run `terraform apply` to revert external change.
# - If resource was changed and you want to preserve that external change without managing it, consider `terraform state rm` to stop managing the resource.
