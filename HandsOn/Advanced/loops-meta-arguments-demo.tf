# loops-meta-arguments-demo.tf
# Comprehensive examples of meta-arguments and control flow in Terraform.

variable "instance_names" {
  type    = list(string)
  default = ["web-1", "web-2"]
}

variable "enable_app" {
  type    = bool
  default = true
}

# ===== FOR_EACH vs COUNT =====

# Example 1: count (indexed, for N identical resources)
resource "null_resource" "with_count" {
  count = var.enable_app ? length(var.instance_names) : 0

  triggers = {
    name = "instance-${count.index}"
  }
}

# Example 2: for_each (keyed, for stable identity)
resource "null_resource" "with_for_each" {
  for_each = toset(var.instance_names)

  triggers = {
    name = each.value
  }
}

# ===== DEPENDS_ON =====

resource "null_resource" "prerequisite" {
  triggers = {
    message = "I must run first"
  }
}

resource "null_resource" "dependent" {
  depends_on = [null_resource.prerequisite]

  triggers = {
    message = "I run after prerequisite"
  }
}

# ===== LIFECYCLE =====

resource "null_resource" "lifecycle_example" {
  triggers = {
    version = "1"
  }

  lifecycle {
    # create_before_destroy: create replacement before destroying old
    create_before_destroy = true

    # ignore_changes: ignore changes to specific attributes
    ignore_changes = [triggers["version"]]

    # prevent_destroy: fail if you try to destroy this resource
    # prevent_destroy = true
  }
}

# ===== TIMEOUTS =====

# Some resources support timeouts (e.g., aws_instance, aws_db_instance)
# Example (pseudocode, not all resources have timeouts):
# resource "aws_instance" "example" {
#   ami           = "ami-123456"
#   instance_type = "t2.micro"
#   
#   timeouts {
#     create = "10m"
#     delete = "5m"
#   }
# }

# Notes:
# - depends_on: explicit dependency order (usually implicit via references)
# - lifecycle: control creation/destruction behavior
# - create_before_destroy: useful for zero-downtime updates
# - ignore_changes: prevent unwanted drift detection or plan diffs
# - prevent_destroy: safety mechanism for critical resources
# - timeouts: override default wait times for resource operations
