# State Backup Demo
# Demonstrates backing up and recovering Terraform state files

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"
}

# Example 1: S3 bucket for storing state backups
resource "aws_s3_bucket" "state_backups" {
  bucket_prefix = "terraform-state-backups-"

  tags = {
    Purpose = "Terraform state file backups"
  }
}

# Example 2: Enable versioning (automatic backup mechanism)
resource "aws_s3_bucket_versioning" "state_backups" {
  bucket = aws_s3_bucket.state_backups.id

  versioning_configuration {
    status = "Enabled"  # Keeps all versions of state files
  }
}

# Example 3: Lifecycle policy to archive old backups
resource "aws_s3_bucket_lifecycle_configuration" "state_backups" {
  bucket = aws_s3_bucket.state_backups.id

  rule {
    id = "archive-old-backups"

    transition {
      days          = 90
      storage_class = "GLACIER"  # Archive to Glacier after 90 days
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    expiration {
      days = 365  # Delete after 1 year
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    status = "Enabled"
  }
}

# Example 4: CloudWatch Logs for state access
resource "aws_cloudwatch_log_group" "state_access" {
  name              = "/terraform/state-access"
  retention_in_days = 30

  tags = {
    Purpose = "Log Terraform state file access"
  }
}

# Example 5: Null resource for backup workflow
resource "null_resource" "backup_trigger" {
  triggers = {
    # Triggers manual backup when changed
    backup_date = "2025-12-11"
  }

  # Backup state periodically
  provisioner "local-exec" {
    command = "echo 'State backup workflow triggered - implement backup script here'"
  }
}

output "state_backup_info" {
  value = "Backups strategy: S3 versioning (automatic) + Glacier archival (90+ days) + CloudTrail logging"
}

# ============================================================================
# STATE BACKUP STRATEGIES
# ============================================================================

# Strategy 1: S3 VERSIONING (Automatic)
# - Enable versioning on state bucket
# - S3 keeps all versions automatically
# - Cost: Storage for multiple versions
# - Recovery: List versions and restore
# Steps:
#   1. Enable versioning on state bucket (done above)
#   2. Each apply creates new version
#   3. Previous versions accessible via S3 API
#   4. Restore by copying old version to current

# Strategy 2: MANUAL BACKUP (Recommended for critical environments)
# PowerShell backup script:
#   $date = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
#   terraform state pull | Out-File -FilePath "backups/state_$date.json"
#   # Or
#   aws s3 cp s3://bucket/key backups/state_$date.tfstate

# Bash backup script:
#   #!/bin/bash
#   DATE=$(date +%Y-%m-%d_%H-%M-%S)
#   terraform state pull > backups/state_$DATE.json
#   # Store backup securely
#   aws s3 cp backups/state_$DATE.json s3://backup-bucket/ --sse AES256

# Strategy 3: BACKUP ON EVERY APPLY
# CI/CD Pipeline backup:
#   1. Before terraform apply, backup state
#   2. Run terraform apply
#   3. On failure, restore from backup
#   4. Store backup in separate S3 bucket

# Example CI/CD (GitHub Actions):
#   - name: Backup state
#     run: |
#       aws s3 cp s3://$STATE_BUCKET/$STATE_KEY \
#         s3://$BACKUP_BUCKET/state-$(date +%s).tfstate
#   - name: Apply Terraform
#     run: terraform apply -auto-approve
#   - name: Verify changes
#     if: failure()
#     run: |
#       aws s3 cp s3://$BACKUP_BUCKET/latest-backup.tfstate \
#         s3://$STATE_BUCKET/$STATE_KEY

# ============================================================================
# BACKUP STRUCTURE (Recommended)
# ============================================================================

# backup/
# ├── daily/
# │   ├── state_2025-12-01.tfstate
# │   ├── state_2025-12-02.tfstate
# │   └── state_2025-12-11.tfstate
# ├── weekly/
# │   ├── state_week_48.tfstate
# │   └── state_week_49.tfstate
# └── monthly/
#     ├── state_2025-11.tfstate
#     └── state_2025-12.tfstate

# ============================================================================
# STATE RECOVERY PROCEDURES
# ============================================================================

# Scenario 1: Restore from recent backup
#   Problem: State file corrupted or lost
#   Solution:
#     1. terraform state pull > current_state.tfstate
#     2. aws s3 cp s3://backup-bucket/state_yyyy-mm-dd.tfstate .
#     3. terraform state push state_yyyy-mm-dd.tfstate -force
#     4. Verify: terraform state list
#     5. Verify: terraform plan (should show no changes)

# Scenario 2: Recover specific resource state
#   Problem: One resource state lost/corrupted
#   Solution:
#     1. terraform state pull > current_state.json
#     2. Identify corrupted resource in JSON
#     3. Compare with backup version
#     4. Fix JSON manually or restore from backup
#     5. terraform state push fixed_state.json -force

# Scenario 3: Recover from deleted S3 object
#   Problem: Someone deleted state file from S3
#   Solution:
#     1. S3 versioning enabled? Restore from previous version
#     2. Backup available? Copy backup back to state bucket
#     3. No backup? Use terraform import to rebuild state
#     4. Prevention: Enable MFA delete, bucket policies

# ============================================================================
# BACKUP COMPLIANCE & AUDIT
# ============================================================================

# Required for regulated environments:

# 1. BACKUP RETENTION POLICY
#    - Daily backups: keep 7 days
#    - Weekly backups: keep 4 weeks
#    - Monthly backups: keep 12 months
#    - Archive: store in separate region
#    - Implement via S3 lifecycle policies (done above)

# 2. BACKUP ENCRYPTION
#    - Backups encrypted at rest (S3-SSE or KMS)
#    - Backups encrypted in transit (HTTPS/TLS)
#    - Encryption keys managed separately
#    - Key rotation enabled (annual minimum)

# 3. BACKUP VERIFICATION
#    - Test recovery procedures quarterly
#    - Verify backup integrity (checksums)
#    - Document recovery time objective (RTO)
#    - Document recovery point objective (RPO)

# 4. BACKUP AUDIT LOGGING
#    - Enable S3 access logging
#    - Enable CloudTrail for API calls
#    - Monitor backup access with CloudWatch
#    - Alert on suspicious access patterns

# 5. BACKUP DOCUMENTATION
#    - Document backup location and schedule
#    - Document recovery procedures
#    - Document contact information
#    - Update runbooks regularly

# ============================================================================
# BACKUP AUTOMATION (PowerShell Example)
# ============================================================================

# Save as: backup-terraform-state.ps1
# powershell -File backup-terraform-state.ps1

# param(
#   [string]$StateBucket = "my-terraform-state",
#   [string]$StateKey = "prod/terraform.tfstate",
#   [string]$BackupBucket = "my-terraform-backups",
#   [string]$Region = "us-east-1"
# )
#
# # Get current state
# $currentDate = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
# $backupKey = "backups/state_$currentDate.tfstate"
#
# try {
#   # Copy current state to backup
#   aws s3 cp "s3://$StateBucket/$StateKey" `
#     "s3://$BackupBucket/$backupKey" `
#     --sse AES256 `
#     --region $Region
#
#   Write-Host "✓ Backup successful: $backupKey"
#
#   # List recent backups
#   aws s3 ls "s3://$BackupBucket/backups/" `
#     --region $Region | Sort-Object -Property @{Expression={$_[0..18] -join ''}} -Descending | Select-Object -First 5
#
# } catch {
#   Write-Error "✗ Backup failed: $_"
#   exit 1
# }

# ============================================================================
