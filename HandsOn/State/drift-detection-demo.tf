# Drift Detection Demo
# Demonstrates detecting and managing infrastructure drift

terraform {
  required_version = ">= 1.0"
}

provider "aws" {
  region = "us-east-1"
}

# Example 1: Security group (prone to drift if rules modified manually)
resource "aws_security_group" "drift_example" {
  name_prefix = "drift-test-"
  description = "Security group to demonstrate drift detection"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "drift-example"
    Drift = "monitored"  # Will drift if manually changed
  }
}

# Example 2: S3 bucket (prone to drift if versioning/encryption changed)
resource "aws_s3_bucket" "drift_demo" {
  bucket_prefix = "drift-"
}

resource "aws_s3_bucket_versioning" "drift_demo" {
  bucket = aws_s3_bucket.drift_demo.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Example 3: Null resource with triggers (detects changes to triggers)
resource "null_resource" "drift_monitor" {
  triggers = {
    config = "version-1"
    owner  = "terraform"
  }
}

output "drift_detection_info" {
  value = "Use terraform plan to detect drift. Manual changes to resources appear as unexpected changes."
}

output "security_group_id" {
  value       = aws_security_group.drift_example.id
  description = "Security group ID - manual rule changes will show as drift"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.drift_demo.id
  description = "S3 bucket - manual versioning/encryption changes will show as drift"
}

# ============================================================================
# DRIFT DETECTION WORKFLOW
# ============================================================================

# Step 1: Define infrastructure with Terraform
#   (Already done above)

# Step 2: Apply configuration
#   terraform apply
#   # Now infrastructure matches state

# Step 3: Manually modify resource in AWS console
#   Example: Add new security group rule manually
#   Example: Enable versioning on S3 bucket
#   Example: Add tag to resource

# Step 4: Detect drift with plan
#   terraform plan
#   # Output shows differences:
#   ~ aws_security_group.drift_example {
#       ~ ingress = [
#           {
#             # New rule added manually (not in Terraform)
#             from_port   = 443
#             to_port     = 443
#             protocol    = "tcp"
#             cidr_blocks = ["192.168.0.0/16"]
#           },
#           # Original rule (in Terraform)
#           {
#             from_port   = 80
#             to_port     = 80
#             protocol    = "tcp"
#             cidr_blocks = ["0.0.0.0/0"]
#           }
#         ]
#     }

# Step 5: Respond to drift
# Option A: Accept drift (don't change anything)
#   terraform apply -auto-approve
#   # State updates to match actual resources (no changes made)

# Option B: Fix drift (modify code and apply)
#   # Update Terraform code to match actual infrastructure
#   terraform apply
#   # Now code and infrastructure match

# Option C: Revert to code (override manual changes)
#   terraform apply -auto-approve
#   # Infrastructure reverted to match Terraform code

# ============================================================================
# DETECTING DRIFT AT SCALE
# ============================================================================

# 1. Use terraform refresh (deprecated, use plan instead)
#    terraform refresh  # Updates state without making changes

# 2. Use terraform plan regularly
#    terraform plan -out=plan.tfplan  # Save plan for review
#    terraform show plan.tfplan       # View plan details

# 3. Use policy as code (Sentinel or OPA)
#    Enforce drift detection in CI/CD
#    Fail apply if drift detected above threshold

# 4. Use cloud/TFE for drift detection
#    terraform cloud automatically detects drift
#    Can schedule refresh intervals

# ============================================================================
# COMMON DRIFT SCENARIOS
# ============================================================================

# Scenario 1: Security group rules modified
#   Cause: Manual rule addition via AWS console
#   Detection: terraform plan shows ingress/egress changes
#   Resolution: Update code or accept drift

# Scenario 2: Tags modified
#   Cause: Cost allocation tags added manually
#   Detection: terraform plan shows tag additions
#   Resolution: Update code with new tags or ignore_changes

# Scenario 3: Resource encryption changed
#   Cause: Enable encryption after creation
#   Detection: terraform plan shows encryption property change
#   Resolution: Recreate resource or ignore_changes

# Scenario 4: IAM policy changed
#   Cause: Permission addition via console
#   Detection: terraform plan shows policy differences
#   Resolution: Update code or ignore_changes

# ============================================================================
# PREVENTING UNWANTED DRIFT
# ============================================================================

# Use lifecycle ignore_changes
resource "null_resource" "prevent_drift" {
  triggers = {
    core_config = "important"
    auto_tags   = "can-be-modified"  # Ignore changes to this
  }

  lifecycle {
    ignore_changes = [
      triggers["auto_tags"]  # Ignore drift on this specific trigger
    ]
  }
}

# Use immutable infrastructure pattern
# Treat infrastructure as immutable - replace instead of modify
# resource "aws_instance" "app" {
#   # Don't modify running instance, replace it
#   lifecycle {
#     create_before_destroy = true  # Blue-green deployment
#   }
# }

# Use infrastructure policies
# Prevent certain modifications:
# - Require tags on all resources
# - Enforce encryption
# - Restrict CIDR ranges
# Implemented via:
# - AWS SCPs (Service Control Policies)
# - Sentinel (HashiCorp policy language)
# - OPA (Open Policy Agent)

# ============================================================================
