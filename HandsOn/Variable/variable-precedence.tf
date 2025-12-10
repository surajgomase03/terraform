# variable-precedence.tf
# Demonstrates variable precedence and examples of how Terraform picks values.

# Declaration with a default
variable "app_name" {
  type    = string
  default = "demo-app"
}

variable "instance_count" {
  type    = number
  default = 1
}

output "current_app_name" {
  value = var.app_name
}

output "current_instance_count" {
  value = var.instance_count
}

# Precedence order (highest -> lowest):
# 1) CLI flags: -var 'name=value'
# 2) Environment variables: TF_VAR_name
# 3) terraform.tfvars or terraform.tfvars.json
# 4) *.auto.tfvars and *.auto.tfvars.json
# 5) Variables defined with default in configuration
# 6) Provider/module defaults (if any)

# Examples to try (PowerShell):
# - Using CLI
#   terraform plan -var='app_name=cli-app' -var='instance_count=3'
# - Using environment variable
#   $env:TF_VAR_app_name = 'env-app'
#   terraform plan
# - Using a var-file
#   create terraform.tfvars with: app_name = "file-app"\ninstance_count = 2
#   terraform plan
# Observe which value wins according to precedence listed above.

# Notes:
# - Use TF_VAR_ environment vars for scripting/CI.
# - Use var-files (-var-file) for environment-specific sets of inputs.
# - Avoid committing sensitive tfvars into VCS; use secret stores.
