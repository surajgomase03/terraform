# conditionals-demo.tf
# Demonstrates Terraform conditionals (ternary operator).

variable "env" {
  type    = string
  default = "dev"
}

variable "enable_high_availability" {
  type    = bool
  default = false
}

# Ternary conditional
output "instance_type" {
  value = var.env == "prod" ? "t3.large" : "t2.micro"
}

# Nested conditionals
output "replica_count" {
  value = (
    var.env == "prod" ? (var.enable_high_availability ? 3 : 1) :
    var.env == "staging" ? 2 :
    1
  )
}

# Conditional with logical operators
output "enable_backup" {
  value = var.env == "prod" || var.enable_high_availability
}

resource "null_resource" "conditional_resource" {
  # count-based conditional: create resource only if condition is true
  count = var.env == "prod" ? 1 : 0
  
  triggers = {
    message = "Created in prod"
  }
}
