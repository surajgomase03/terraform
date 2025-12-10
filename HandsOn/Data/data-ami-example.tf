# data-ami-example.tf
# Simple examples showing aws_ami data lookups (read-only).
# This file is safe to run if you have AWS provider configured.

variable "region" {
  type    = string
  default = "us-east-1"
}

# Most recent Amazon Linux 2 AMI (can change between runs)
data "aws_ami" "amazon_linux_latest" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Deterministic lookup by tag or explicit filter (preferred for production)
# Example: lookup by specific name pattern and owner
data "aws_ami" "amazon_linux_by_name" {
  most_recent = false
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.0.*-x86_64-gp2"]
  }
}

output "latest_ami_id" {
  value = data.aws_ami.amazon_linux_latest.id
}

output "fixed_ami_id" {
  value = data.aws_ami.amazon_linux_by_name.id
}

# Example usage note:
# - Prefer deterministic lookups (explicit name or tag) for production to avoid unexpected replacements.
# - Use 'most_recent = true' for quick demos but mention the risk in interviews.
