# Version Pinning Demo
# Demonstrates version constraints for providers, modules, and Terraform

terraform {
  # Terraform version constraint
  required_version = ">= 1.5, < 2.0"

  required_providers {
    # AWS Provider Version Constraints
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"       # Allow patch updates (5.0.x, 5.1.x, etc.)
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ============================================================================
# VERSION CONSTRAINT OPERATORS
# ============================================================================

# Operator    | Meaning                          | Example
# ============================================================================================================
# =           | Exact version only               | version = "2.0.0"
# !=          | Exclude specific version         | version = "!= 2.0.0"
# >           | Greater than                     | version = "> 2.0.0" (allows 2.0.1, 2.1.0, 3.0.0)
# >=          | Greater than or equal            | version = ">= 2.0.0"
# <           | Less than                        | version = "< 3.0.0"
# <=          | Less than or equal               | version = "<= 3.0.0"
# ~>          | Pessimistic constraint (RECOMMENDED) | version = "~> 5.0"
# >=,<        | Range                            | version = ">= 2.0, < 3.0"

# ============================================================================
# PESSIMISTIC CONSTRAINT OPERATOR (~>) — RECOMMENDED
# ============================================================================

# ~> 5.0 means: >= 5.0.0 and < 6.0.0
#   Allows: 5.0.0, 5.1.0, 5.99.0
#   Blocks:  4.99.0, 6.0.0

# ~> 5.23 means: >= 5.23.0 and < 5.24.0
#   Allows: 5.23.0, 5.23.1, 5.23.99
#   Blocks:  5.22.0, 5.24.0

# Why use ~>?
# - Automatic patch updates (security fixes)
# - Blocks major/minor breaking changes
# - Sweet spot for stability vs bug fixes
# - Industry standard

# ============================================================================
# PROVIDER VERSION PINNING EXAMPLES
# ============================================================================

# Example 1: AWS Provider (most common)
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"  # Allow 5.x.y updates
#     }
#   }
# }

# Example 2: Multiple Providers
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 5.0"
#     }
#     azurerm = {
#       source  = "hashicorp/azurerm"
#       version = "~> 3.0"
#     }
#     google = {
#       source  = "hashicorp/google"
#       version = "~> 5.0"
#     }
#   }
# }

# Example 3: Strict Versioning
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "= 5.23.0"  # Exact version only
#     }
#   }
# }

# Example 4: Range Constraints
# terraform {
#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = ">= 5.0, < 6.0"  # Same as ~> 5.0
#     }
#   }
# }

# ============================================================================
# MODULE VERSION PINNING (Remote Modules)
# ============================================================================

# Public Registry Module with Version
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"  # Allow 5.x updates

  name = "example-vpc"
  # ... other inputs
}

# Another public module with strict versioning
module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.1"  # Allow 5.1.x and 5.2.x, but not 5.0.x or 6.0.x

  name = "example-sg"
  # ... other inputs
}

# Local modules (no version pinning)
module "custom_app" {
  source = "./modules/app"  # No version for local modules
  name   = "example"
}

# Git-based module with version (tag or branch)
# module "remote_module" {
#   source = "git::https://github.com/company/terraform-module.git"
#   version = "v1.2.0"  # Git tag
#   name = "example"
# }

# ============================================================================
# TERRAFORM VERSION PINNING
# ============================================================================

# Terraform version constraint (affects terraform binary, not providers)

# Example 1: Allow any 1.x version (not 2.0)
# terraform {
#   required_version = ">= 1.0, < 2.0"
# }

# Example 2: Pessimistic constraint
# terraform {
#   required_version = "~> 1.5"  # >= 1.5.0, < 1.6.0
# }

# Example 3: Minimum version only
# terraform {
#   required_version = ">= 1.5"  # 1.5.0 or higher
# }

# Example 4: Specific version range
# terraform {
#   required_version = ">= 1.5, < 1.6"
# }

# ============================================================================
# VERSION PINNING BEST PRACTICES
# ============================================================================

# 1. USE PESSIMISTIC OPERATOR (~>)
#    ✓ version = "~> 5.0"    (Safe, automatic updates)
#    ✗ version = ">= 5.0"    (Too permissive, may break)
#    ✗ version = "= 5.0.0"   (Too strict, no fixes)

# 2. PIN MAJOR VERSION ONLY
#    ✓ version = "~> 5.0"    (Allow 5.x.y)
#    ✓ version = "~> 5.23"   (Allow 5.23.x)
#    ✗ version = "~> 5.23.1" (Too restrictive)

# 3. DOCUMENT WHY YOU PINNED
#    # AWS provider 5.0 required for new resource type
#    version = "~> 5.0"

# 4. REGULARLY UPDATE VERSIONS
#    - Review provider releases monthly
#    - Update to latest patch (5.0.x → 5.1.x)
#    - Test before updating major (5.x → 6.x)

# 5. USE .terraform.lock.hcl
#    Terraform creates lock file automatically:
#    - Tracks exact versions used
#    - Ensures team uses same versions
#    - Commit to version control

# Example .terraform.lock.hcl content:
# terraform_required_version = "1.5.0"
# provider "registry.terraform.io/hashicorp/aws" {
#   version = "5.23.0"
#   ...
# }

# 6. TEST VERSION UPGRADES
#    # Before upgrading:
#    terraform plan > current_plan.txt
#
#    # Update version in code
#    # Commit to feature branch
#    # Test in dev environment
#    terraform init
#    terraform plan > new_plan.txt
#    
#    # Compare plans
#    diff current_plan.txt new_plan.txt

# 7. VERSION UPGRADES IN CI/CD
#    - Create separate branch for version bump
#    - Run full test suite
#    - Merge to main only after passing tests
#    - Tag release version

# 8. MAINTAIN COMPATIBILITY MATRIX
#    # Document what works with what
#    # terraform-versions.md
#    | Module Version | AWS Provider | Terraform |
#    |---|---|---|
#    | 1.0 | ~> 4.0 | >= 1.0 |
#    | 2.0 | ~> 5.0 | >= 1.2 |

# ============================================================================
# DEPENDENCY MANAGEMENT EXAMPLE
# ============================================================================

# Good version strategy for a project:
terraform {
  required_version = "~> 1.5"  # Terraform 1.5.x

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # AWS provider 5.x
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"  # Null provider 3.2.x
    }
  }
}

# Public modules
module "vpc_module" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  # ...
}

# Local modules (no version pinning)
module "custom_security" {
  source = "./modules/security"
  # ...
}

# ============================================================================
# VERSION PINNING TROUBLESHOOTING
# ============================================================================

# Issue 1: "No matching version found"
# Cause: Version constraint too restrictive
# Solution: Relax constraint (use ~> instead of =)
#   terraform {
#     required_providers {
#       aws = {
#         version = ">= 5.0"  # More flexible
#       }
#     }
#   }

# Issue 2: "Provider version changed between plans"
# Cause: No lock file or lock file not committed
# Solution: Commit .terraform.lock.hcl to version control
#   git add .terraform.lock.hcl
#   git commit -m "Update provider lock file"

# Issue 3: "Incompatible with module version X"
# Cause: Provider version doesn't support module
# Solution: Check module documentation for required provider version
#   Module requires: aws >= 4.0
#   Your version:    aws = 3.x
#   Fix: Update to aws = "~> 4.0"

# ============================================================================
# VERSION PINNING CHECKLIST
# ============================================================================

# [ ] Terraform version pinned (required_version)
# [ ] Provider versions pinned (required_providers)
# [ ] Module versions pinned (for public/remote)
# [ ] .terraform.lock.hcl committed to git
# [ ] Version constraints documented
# [ ] Upgrade procedure documented
# [ ] Regular version review scheduled
# [ ] Testing performed on version updates
# [ ] Breaking changes reviewed before major updates
# [ ] Team trained on version management

# ============================================================================
