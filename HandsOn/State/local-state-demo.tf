# Local State Configuration Demo
# Demonstrates default local state storage and best practices

terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# Example 1: Simple resource (state stored in terraform.tfstate by default)
resource "null_resource" "local_state_example" {
  triggers = {
    message = "This state is stored locally in terraform.tfstate"
  }
}

# Example 2: Using local-exec provisioner (demonstrates local state tracking)
resource "null_resource" "local_execution" {
  provisioner "local-exec" {
    command = "echo 'Local state tracked for provisioner execution'"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "echo 'Cleaning up local execution state'"
  }
}

# Example 3: File provisioner with local state tracking
resource "null_resource" "file_tracking" {
  triggers = {
    config_file = "app.conf"
  }

  provisioner "local-exec" {
    command = "echo 'State change recorded for file: ${self.triggers.config_file}'"
  }
}

# Output local state information
output "terraform_version" {
  value       = "Local state will be in terraform.tfstate (not .terraform folder)"
  description = "State storage location"
}

output "state_file_location" {
  value       = "Current working directory / terraform.tfstate"
  description = "Where Terraform stores local state by default"
}

# Best practices for local state:
# 1. Always commit terraform.tfvars to version control (with secrets excluded)
# 2. Never commit terraform.tfstate to version control
# 3. Use .gitignore to exclude *.tfstate and *.tfstate.* files
# 4. Add terraform.tfstate to .gitignore
# 5. For team projects, migrate to remote state early

# Example .gitignore entries:
# terraform.tfstate
# terraform.tfstate.*
# .terraform/
# *.tfvars
# override.tf*
