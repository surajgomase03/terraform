# State Manipulation Demo
# Demonstrates terraform state commands for direct state editing and resource management

terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# Example 1: Resource for state manipulation demos
resource "null_resource" "state_move_example" {
  triggers = {
    name = "original-resource"
  }
}

# Example 2: Another resource for state operations
resource "null_resource" "state_remove_example" {
  triggers = {
    purpose = "demonstrate removal from state"
  }
}

# Example 3: Multiple resources in a module-like structure
resource "null_resource" "state_import_example" {
  triggers = {
    id = "external-resource-id"
  }
}

# Example 4: Resource to demonstrate taint/untaint
resource "null_resource" "state_taint_example" {
  triggers = {
    version = "1.0"
  }
}

output "state_manipulation_info" {
  value = "Use terraform state commands to manage resources without applying changes"
}

# Common terraform state manipulation commands:

# 1. terraform state list
#    Lists all resources in state file
#    Example: terraform state list
#    Output: null_resource.state_move_example

# 2. terraform state show <resource>
#    Shows detailed state of specific resource
#    Example: terraform state show null_resource.state_move_example
#    Output: Shows triggers, id, metadata

# 3. terraform state mv <source> <destination>
#    Moves/renames resource in state (without destroying actual resource)
#    Example: terraform state mv null_resource.old_name null_resource.new_name
#    Use case: Refactoring module names or resource names

# 4. terraform state rm <resource>
#    Removes resource from state (doesn't destroy actual cloud resource)
#    Example: terraform state rm null_resource.state_remove_example
#    Use case: Remove resource from Terraform management (but keep it in cloud)

# 5. terraform state pull
#    Reads state file and outputs to stdout (useful for inspection)
#    Example: terraform state pull > current.tfstate
#    Use case: Backup, inspection, auditing

# 6. terraform state push <file>
#    Replaces state file with provided file (dangerous, requires -force for remote)
#    Example: terraform state push backup.tfstate -force
#    Use case: Recovery from state corruption

# 7. terraform taint <resource>
#    Marks resource for destruction and recreation on next apply
#    Example: terraform taint null_resource.state_taint_example
#    Use case: Force replacement without code changes

# 8. terraform untaint <resource>
#    Removes taint marker, resource won't be replaced on next apply
#    Example: terraform untaint null_resource.state_taint_example
#    Use case: Undo accidental taint

# 9. terraform state replace-provider <old_provider> <new_provider>
#    Replaces provider for all resources in state
#    Example: terraform state replace-provider 'registry.terraform.io/-/aws' 'registry.terraform.io/hashicorp/aws'
#    Use case: Provider migration

# 10. terraform import <resource> <id>
#     Adds existing cloud resource to state (must define resource in code first)
#     Example: terraform import aws_instance.example i-1234567890abcdef0
#     Use case: Adopt existing resources into Terraform
