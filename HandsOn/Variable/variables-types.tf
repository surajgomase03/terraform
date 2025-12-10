# variables-types.tf
# Demonstrates Terraform variable types and simple usage examples.

# String
variable "app_name" {
  description = "Application name"
  type        = string
  default     = "demo-app"
}

# Number
variable "instance_count" {
  description = "Number of instances to create"
  type        = number
  default     = 2
}

# Boolean
variable "enable_monitoring" {
  description = "Enable monitoring"
  type        = bool
  default     = true
}

# List
variable "availability_zones" {
  description = "List of AZs to use"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# Map
variable "default_tags" {
  description = "Map of default tags"
  type        = map(string)
  default = {
    Owner = "dev"
    Env   = "demo"
  }
}

# Object
variable "db_config" {
  description = "Database configuration object"
  type = object({
    engine   = string
    version  = string
    replicas = number
  })
  default = {
    engine   = "postgres"
    version  = "13"
    replicas = 1
  }
}

# Use variables in dummy resources (null_resource used for examples only)
resource "null_resource" "example" {
  count = var.instance_count

  triggers = {
    app        = var.app_name
    az         = element(var.availability_zones, count.index % length(var.availability_zones))
    monitoring = tostring(var.enable_monitoring)
    tags       = jsonencode(var.default_tags)
    db_engine  = var.db_config.engine
    db_ver     = var.db_config.version
  }
}

output "example_summary" {
  value = {
    app                 = var.app_name
    instance_count      = var.instance_count
    enable_monitoring   = var.enable_monitoring
    availability_zones  = var.availability_zones
    default_tags        = var.default_tags
    db_config           = var.db_config
  }
}
