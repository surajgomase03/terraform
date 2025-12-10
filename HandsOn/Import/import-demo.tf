# import-demo.tf
# Demonstrates how to import an existing resource into Terraform state.
# WARNING: Don't run without configuring provider and being careful about real resources.

# Example: import an existing security group by id into this config.
resource "aws_security_group" "imported_sg" {
  # after import, update this block to match existing attributes
  name        = "imported-sg"
  description = "Imported SG"
  vpc_id      = "" # fill after import with data or known id
}

# After creating a matching resource block for the real resource, run:
# terraform import aws_security_group.imported_sg sg-0123456789abcdef0

# Then run:
# terraform plan
# and update the resource block to match the imported resource to avoid replacements.
