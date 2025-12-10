# State Backup — Interview Notes

## Quick Definition
State backups protect against state file loss/corruption by keeping multiple copies with version history and recovery procedures.

## Q&A Format

### Q: Why backup state?
**A:** 
State file is single source of truth:
- Loss = can't manage infrastructure with Terraform
- Corruption = infrastructure becomes orphaned
- Disaster recovery = restore from backup
- Compliance = audit trail of infrastructure changes

### Q: What to backup?
**A:** 
- `terraform.tfstate` (main state file)
- `terraform.tfstate.backup` (previous state)
- State in remote backend (S3 has versions)
- State metadata (lock information)

### Q: S3 backend (automatic backup)?
**A:** 
Yes, via versioning:
```hcl
# Enable versioning on state bucket
resource "aws_s3_bucket_versioning" "state" {
  bucket = "my-terraform-state"
  
  versioning_configuration {
    status = "Enabled"  # Keep all versions
  }
}

# Behavior:
# - Every apply creates new version
# - All versions accessible via S3 API
# - Cost: Storage for each version (~$0.023/GB/month)
# - Recovery: aws s3 cp <version> current
```

### Q: Manual backup (best practice)?
**A:** 
```powershell
# Backup before critical changes
terraform state pull > "backup_$(Get-Date -f 'yyyy-MM-dd_HH-mm-ss').tfstate"

# Store in secure location:
# - Separate S3 bucket (different region/account)
# - Encrypted
# - Versioned
# - Restricted access (backup admins only)
```

### Q: Backup automation (CI/CD)?
**A:** 
```yaml
# GitHub Actions example
- name: Backup state before apply
  run: |
    aws s3 cp s3://terraform-state/prod/tfstate \
      s3://terraform-backups/pre-apply-$(date +%s).tfstate \
      --sse AES256
  
- name: Terraform Apply
  run: terraform apply -auto-approve

- name: Backup state after apply
  if: success()
  run: |
    aws s3 cp s3://terraform-state/prod/tfstate \
      s3://terraform-backups/post-apply-$(date +%s).tfstate \
      --sse AES256
```

### Q: Backup retention policy?
**A:** 
Recommended:
- Daily: 7 days
- Weekly: 4 weeks
- Monthly: 12 months
- Archive: Indefinite (Glacier)

Implementation:
```hcl
resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = "terraform-backups"
  
  rule {
    id = "archive-old-backups"
    
    # Move to Glacier after 90 days
    transition {
      days          = 90
      storage_class = "GLACIER"
    }
    
    # Delete after 1 year
    expiration {
      days = 365
    }
    
    status = "Enabled"
  }
}
```

### Q: Restore from backup (procedure)?
**A:** 
```powershell
# Step 1: Verify backup integrity
Get-Item backup_2025-12-11.tfstate
# Check file size, date, permissions

# Step 2: Backup current state (before restore!)
terraform state pull > state_before_restore.tfstate

# Step 3: Restore backup
terraform state push backup_2025-12-11.tfstate -force

# Step 4: Verify restored state
terraform state list
terraform state show <resource>

# Step 5: Run plan (verify state matches infrastructure)
terraform plan  # Should show no changes (or expected changes)

# Step 6: If ok, continue. If not, restore previous backup
```

### Q: Backup encryption?
**A:** 
Always encrypt backups:
```powershell
# Backup with S3 encryption
terraform state pull | aws s3 cp - s3://backup-bucket/state.json \
  --sse AES256

# Or with KMS
aws s3 cp state-backup.json s3://backup-bucket/ \
  --sse aws:kms \
  --sse-kms-key-id arn:aws:kms:us-east-1:...
```

### Q: Backup versioning?
**A:** 
Enable S3 versioning on backup bucket:
```hcl
resource "aws_s3_bucket_versioning" "backups" {
  bucket = "terraform-backups"
  
  versioning_configuration {
    status = "Enabled"  # Keep all backup versions
  }
}
```

### Q: Backup access control?
**A:** 
Restrict access with IAM:
```hcl
resource "aws_s3_bucket_policy" "backups" {
  bucket = "terraform-backups"
  
  policy = jsonencode({
    Statement = [
      {
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          "arn:aws:s3:::terraform-backups",
          "arn:aws:s3:::terraform-backups/*"
        ]
        Condition = {
          StringNotLike = {
            "aws:SourceArn" = "arn:aws:iam::123456789012:role/BackupAdmin"
          }
        }
      }
    ]
  })
}
```

### Q: Test backup recovery?
**A:** 
Important for disaster recovery:
```powershell
# Quarterly: Test recovery procedure
# 1. Create test environment
# 2. Restore from backup
# 3. Verify infrastructure matches
# 4. Document results
# 5. Update runbooks if needed
```

### Q: Backup documentation?
**A:** 
Document for disaster recovery:
```markdown
# Terraform State Backup Runbook

## Backup Location
- S3 bucket: terraform-backups-prod
- Region: us-east-1
- Retention: 1 year

## Backup Schedule
- Daily backups at 03:00 UTC
- Pre/post apply backups
- Manual backup before major changes

## Recovery Procedure
1. Identify need for recovery
2. Get backup file ID
3. Run: terraform state push <file>
4. Verify: terraform state list
5. Run: terraform plan
6. Document incident ticket

## Contact
- On-call: terraform-admin@company.com
- Escalation: infrastructure@company.com
```

### Q: Backup in Terraform Cloud?
**A:** 
Automatic (no manual setup):
- State versioning built-in
- Automatic daily backups
- State retention (30+ days)
- One-click restore from UI
- No additional cost

### Q: Disaster recovery (total loss)?
**A:** 
If backup lost/corrupted:
```powershell
# Rebuild state from cloud resources
# For each resource:
# 1. Define in Terraform code
# 2. terraform import <resource> <id>
# 3. Verify with terraform plan

# This reconstructs state from actual resources
# Time-consuming but possible
```

### Q: Backup validation?
**A:** 
Verify backup is usable:
```powershell
# Check file format (JSON)
Get-Content backup.tfstate | ConvertFrom-Json

# Verify structure
$state = Get-Content backup.tfstate | ConvertFrom-Json
$state.version
$state.resources.length
# Should match previous state structure
```

### Q: Compliance backup requirements?
**A:** 
Regulated environments (HIPAA, PCI-DSS):
- Backup encryption required
- Audit logging required
- Retention policy documented
- Recovery procedure tested
- Disaster recovery plan
- Backup isolation (separate account)
- Immutable backups (MFA delete)

---

## Backup Strategy Comparison

| Strategy | Cost | Effort | Recovery Time | Data Loss |
|----------|------|--------|----------------|-----------|
| S3 versioning | Low | None | < 1 min | None |
| Manual backup | Low | Medium | 5-10 min | Last backup |
| CI/CD pre/post | Medium | High | < 1 min | None |
| Terraform Cloud | High | None | < 1 min | None |
| Cross-region replica | High | Medium | 1-5 min | None |

**Recommended**: Combination of S3 versioning + CI/CD pre-apply backup + quarterly recovery test

---

## Key Takeaway
Always backup before critical changes. Use S3 versioning for automatic backups. Test recovery procedures regularly. Document all procedures in runbooks.
