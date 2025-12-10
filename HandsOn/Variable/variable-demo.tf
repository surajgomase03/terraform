# variable-demo.tf
# Demonstrates variable declaration, types, and passing via tfvars

variable "instance_count" {
  type    = number
  default = 2
}

variable "tags" {
  type = map(string)
  default = {
    Owner = "dev"
    Env   = "demo"
  }
}

resource "null_resource" "count_demo" {
  count = var.instance_count

  triggers = {
    index = tostring(count.index)
    tags  = jsonencode(var.tags)
  }
}

# Use a terraform.tfvars file or -var-file to override values in CI
# Example: terraform plan -var-file="terraform.tfvars"
