# Terraform State Commands Demo
# Comprehensive guide to all terraform state subcommands

terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# Example resources to demonstrate state commands
resource "null_resource" "app_server" {
  triggers = {
    name = "app-server"
    tier = "application"
  }
}

resource "null_resource" "db_server" {
  triggers = {
    name = "db-server"
    tier = "database"
  }

  depends_on = [null_resource.app_server]
}

resource "null_resource" "cache_server" {
  triggers = {
    name    = "cache-server"
    tier    = "cache"
    version = "1.0"
  }
}

output "terraform_state_commands_guide" {
  value = "See comments below for all terraform state subcommands and examples"
}

# ============================================================================
# TERRAFORM STATE COMMAND REFERENCE
# ============================================================================

# MAIN SUBCOMMANDS:
# ----------------

# 1. terraform state list
#    Purpose: List all resources in state
#    Syntax:  terraform state list [<options>] [<resource_prefix>]
#    Examples:
#      terraform state list
#      terraform state list null_resource.*
#      terraform state list | grep app
#    Output:
#      null_resource.app_server
#      null_resource.db_server
#      null_resource.cache_server

# 2. terraform state show
#    Purpose: Show state of specific resource
#    Syntax:  terraform state show [<options>] <resource_address>
#    Examples:
#      terraform state show null_resource.app_server
#      terraform state show 'null_resource.app_server[0]'
#    Output:
#      resource "null_resource" "app_server" {
#        triggers = {
#          "name" = "app-server"
#          "tier" = "application"
#        }
#      }

# 3. terraform state mv
#    Purpose: Move resource in state (rename/relocate without recreation)
#    Syntax:  terraform state mv [<options>] <source> <destination>
#    Examples:
#      terraform state mv null_resource.app_server null_resource.application_server
#      terraform state mv 'aws_instance.example[0]' 'aws_instance.example[1]'
#      terraform state mv module.old.aws_instance.web module.new.aws_instance.web
#    Use cases:
#      - Rename resource in code without recreation
#      - Move resource between modules
#      - Fix resource address mismatches

# 4. terraform state rm
#    Purpose: Remove resource from state (unmanage without destroying)
#    Syntax:  terraform state rm [<options>] <resource_address>
#    Examples:
#      terraform state rm null_resource.app_server
#      terraform state rm aws_instance.web
#      terraform state rm 'aws_instance.example[0]'
#    Use cases:
#      - Remove from Terraform management (keep cloud resource)
#      - Stop managing a resource
#      - Clean up state after manual cleanup

# 5. terraform state pull
#    Purpose: Print current state to stdout
#    Syntax:  terraform state pull > <file>
#    Examples:
#      terraform state pull
#      terraform state pull > state-backup.json
#    Output: JSON representation of entire state
#    Use cases:
#      - Backup state
#      - Inspect state structure
#      - Debug state issues
#      - Audit state contents

# 6. terraform state push
#    Purpose: Replace state file with new state
#    Syntax:  terraform state push [<options>] <path>
#    Examples:
#      terraform state push state-backup.json
#      terraform state push -force state-backup.json  # For remote state
#    WARNING: This is dangerous! Only use for recovery.
#    Use cases:
#      - Recover from state corruption
#      - Restore from backup (last resort)
#      - Migrate state between backends

# 7. terraform taint
#    Purpose: Mark resource for destruction and recreation
#    Syntax:  terraform taint [<options>] <resource_address>
#    Examples:
#      terraform taint null_resource.app_server
#      terraform taint 'aws_instance.example[2]'
#    Effect: Next `terraform apply` will destroy and recreate the resource
#    Use cases:
#      - Force replacement due to issues
#      - Rotate keys/certificates
#      - Update without code change

# 8. terraform untaint
#    Purpose: Remove taint marker (cancel forced replacement)
#    Syntax:  terraform untaint [<options>] <resource_address>
#    Examples:
#      terraform untaint null_resource.app_server
#      terraform untaint 'aws_instance.example[2]'
#    Effect: Next `terraform apply` will not replace the resource
#    Use cases:
#      - Undo accidental taint
#      - Cancel forced replacement

# 9. terraform state replace-provider
#    Purpose: Replace provider for resources in state
#    Syntax:  terraform state replace-provider <old_provider> <new_provider>
#    Examples:
#      terraform state replace-provider \
#        'registry.terraform.io/-/aws' \
#        'registry.terraform.io/hashicorp/aws'
#      terraform state replace-provider \
#        'registry.terraform.io/hashicorp/vault' \
#        'registry.terraform.io/hashicorp/vault'
#    Use cases:
#      - Migrate to new provider
#      - Update provider registry path

# 10. terraform import
#     Purpose: Add existing resource to state
#     Syntax:  terraform import [<options>] <resource_type>.<name> <id>
#     Examples:
#       terraform import aws_instance.example i-0123456789abcdef0
#       terraform import aws_security_group.allow sg-0123456789abcdef0
#       terraform import aws_s3_bucket.data my-bucket
#     Prerequisites:
#       1. Define the resource in your Terraform code (without body)
#       2. Run terraform import with resource ID
#       3. State entry is created; configure resource details
#     Use cases:
#       - Adopt existing cloud resource
#       - Import manually created infrastructure
#       - Bring resources under Terraform management

# ============================================================================
# STATE INSPECTION WORKFLOWS
# ============================================================================

# Workflow 1: Backup state before modifications
#   terraform state pull > backup-$(date +%s).tfstate

# Workflow 2: List and inspect all resources
#   terraform state list
#   terraform state show <resource>

# Workflow 3: Move resource to new name
#   terraform state mv old.name new.name
#   # Update code to match
#   terraform plan

# Workflow 4: Remove resource from management
#   terraform state rm resource.address
#   terraform plan  # Should show resource destroyed

# Workflow 5: Force replacement
#   terraform taint resource.address
#   terraform plan  # Shows resource for recreation
#   terraform apply

# ============================================================================
# COMMON STATE COMMAND OPTIONS
# ============================================================================

# Global options (apply to most state commands):
#   -lock=true/false      Lock state during operation (default: true)
#   -lock-timeout=5m      Wait time for state lock (default: 0s)
#   -backup=<path>        Create backup of state before modification
#   -var <key>=<value>    Set Terraform variable (for resource address)
#   -var-file=<path>      Load variables from file

# ============================================================================
