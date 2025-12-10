# variables-validation.tf
# Examples of Terraform variable validation (Terraform 0.13+)

variable "port" {
  description = "Application port"
  type        = number
  default     = 8080

  validation {
    condition     = var.port >= 1024 && var.port <= 65535
    error_message = "Port must be between 1024 and 65535."
  }
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev","staging","prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

# Use the variables in a simple null_resource for demonstration
resource "null_resource" "validation_demo" {
  triggers = {
    port        = tostring(var.port)
    environment = var.environment
  }
}

output "validated_port" {
  value = var.port
}

output "validated_environment" {
  value = var.environment
}

# To test validation locally:
# 1) terraform init
# 2) terraform plan -var='port=80'   # will fail validation with custom message
# 3) terraform plan -var='port=8080' # valid
# 4) terraform plan -var='environment=qa' # will fail validation
