# for-loops-demo.tf
# Demonstrates Terraform for loops and for expressions.

variable "subnets" {
  type = list(string)
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "instance_names" {
  type = list(string)
  default = ["web-1", "web-2", "web-3"]
}

# for expression on list: iterate and collect values
output "uppercase_names" {
  value = [for name in var.instance_names : upper(name)]
}

# for expression with index
output "indexed_names" {
  value = [for i, name in var.instance_names : "${i}: ${name}"]
}

# for expression on map
variable "tags" {
  type = map(string)
  default = {
    Owner = "team-a"
    Env   = "dev"
  }
}

output "tag_strings" {
  value = [for key, value in var.tags : "${key}=${value}"]
}

# for expression with filter (if condition)
output "filtered_subnets" {
  value = [for subnet in var.subnets : subnet if substr(subnet, 0, 5) == "10.0."]
}

# Using for with count-based resources
resource "null_resource" "instance" {
  count = length(var.instance_names)

  triggers = {
    name = var.instance_names[count.index]
  }
}
