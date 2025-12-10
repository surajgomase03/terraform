# dynamic-blocks-demo.tf
# Demonstrates Terraform dynamic blocks for repeating nested arguments.

variable "rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Example: simulate ingress rules using dynamic block
# (In reality, you would use aws_security_group_rule resources)
output "rules_summary" {
  value = [
    for rule in var.rules : {
      port_range = "${rule.from_port}-${rule.to_port}"
      protocol   = rule.protocol
      cidr_blocks = join(",", rule.cidr_blocks)
    }
  ]
}

# Dynamic block example (pseudo-code for illustration):
# resource "aws_security_group" "example" {
#   dynamic "ingress" {
#     for_each = var.rules
#     content {
#       from_port   = ingress.value.from_port
#       to_port     = ingress.value.to_port
#       protocol    = ingress.value.protocol
#       cidr_blocks = ingress.value.cidr_blocks
#     }
#   }
# }
