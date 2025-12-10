# for_each example using null_resource

locals {
  servers = {
    web = { port = 80 }
    app = { port = 8080 }
  }
}

resource "null_resource" "server" {
  for_each = local.servers

  # Use triggers to make resources depend on values and to demonstrate each.value
  triggers = {
    name = each.key
    port = tostring(each.value.port)
  }
}

# Reference example:
# - Resource for key "web": null_resource.server["web"].id
# - Looping in other resources: each.key, each.value
