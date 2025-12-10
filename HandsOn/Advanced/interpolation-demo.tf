# interpolation-demo.tf
# Demonstrates Terraform string interpolation (embedding expressions in strings).

variable "app_name" {
  type    = string
  default = "myapp"
}

variable "env" {
  type    = string
  default = "dev"
}

variable "port" {
  type    = number
  default = 8080
}

# Basic interpolation
output "simple_interpolation" {
  value = "App: ${var.app_name}, Env: ${var.env}"
}

# Interpolation with function calls
output "with_functions" {
  value = "App name is ${upper(var.app_name)}"
}

# Interpolation with arithmetic
output "with_arithmetic" {
  value = "Port range: ${var.port} to ${var.port + 1000}"
}

# Interpolation with conditionals
output "with_conditional" {
  value = "Environment is ${var.env == "prod" ? "PRODUCTION" : "non-production"}"
}

# Multi-line interpolation
output "multi_line" {
  value = <<-EOT
Application: ${var.app_name}
Environment: ${var.env}
Port: ${var.port}
  EOT
}

# Interpolation in resource naming
resource "null_resource" "named_resource" {
  triggers = {
    name = "${var.app_name}-${var.env}-resource"
  }
}
