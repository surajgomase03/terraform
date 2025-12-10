# count example using null_resource

variable "instance_count" {
  type    = number
  default = 2
}

resource "null_resource" "web" {
  count = var.instance_count

  triggers = {
    index = tostring(count.index)
  }
}

# Reference example:
# - First instance: null_resource.web[0].id
# - Use count.index inside the resource for indexing
