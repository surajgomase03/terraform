# expressions-demo.tf
# Demonstrates Terraform expressions: literals, variable references, conditionals, functions.

variable "enable_feature" {
  type    = bool
  default = true
}

variable "port" {
  type    = number
  default = 8080
}

# Expression examples: literal, variable reference, arithmetic, function calls
output "literal_string" {
  value = "Hello, Terraform"
}

output "variable_ref" {
  value = var.port
}

output "arithmetic" {
  value = var.port + 100
}

output "function_call" {
  value = upper("terraform rocks")
}

output "conditional_expr" {
  value = var.enable_feature ? "Feature enabled" : "Feature disabled"
}

output "complex_expression" {
  value = var.enable_feature ? var.port : 0
}
