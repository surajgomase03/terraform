# KMS Encryption Interview Guide

## Q1: What is AWS KMS and why use it with Terraform?

**Answer:**
AWS Key Management Service (KMS) is a managed cryptographic service that helps you create and manage encryption keys. It's used to encrypt sensitive data at rest across AWS services.

**Why with Terraform:**
- **Compliance:** Meet regulatory requirements (HIPAA, PCI-DSS, SOC 2)
- **Security:** Customer-managed keys give you full control
- **Audit:** CloudTrail logs all key usage
- **Rotation:** Automatic yearly rotation of key material
- **Cost:** Pay per key and per request

**Example use cases:**
- Encrypt RDS databases
- Encrypt S3 buckets
- Encrypt Secrets Manager
- Encrypt CloudWatch Logs
- Encrypt Terraform state in S3

---

## Q2: How do you create and manage KMS keys in Terraform?

**Answer:**
Use `aws_kms_key` resource and optionally `aws_kms_alias` for human-readable names.

**Key properties:**
| Property | Purpose | Example |
|----------|---------|---------|
| `description` | Key purpose | "Database encryption key" |
| `deletion_window_in_days` | Recovery period | 30 days |
| `enable_key_rotation` | Auto-rotate yearly | true |
| `policy` | Grant permissions to services | S3, RDS, Secrets Manager |

**Creating a key:**
```hcl
resource "aws_kms_key" "database" {
  description             = "RDS database encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  
  tags = {
    Name    = "database-key"
    Purpose = "RDS"
  }
}

resource "aws_kms_alias" "database" {
  name          = "alias/database-encryption"
  target_key_id = aws_kms_key.database.key_id
}
```

**Deletion safety:**
- `deletion_window_in_days`: Grace period to recover before deletion
- After window expires, key is permanently deleted
- Best practice: Set to 30 days for critical keys

---

## Q3: What's the difference between AWS managed and customer managed keys?

**Comparison Table:**

| Aspect | AWS Managed | Customer Managed |
|--------|-------------|------------------|
| **Creation** | AWS creates for service | You create in Terraform |
| **Key Rotation** | Auto-rotated | You control rotation |
| **Cost** | Free | Pay per key + requests |
| **Key Policy** | Fixed (cannot change) | You define policy |
| **Use Case** | Default encryption | Full control needed |
| **Compliance** | Basic | Advanced (HIPAA, PCI) |
| **Key ID** | aws/service format | Looks like: arn:aws:kms:... |

**When to use customer managed:**
- ✓ Compliance requirements (HIPAA, PCI-DSS, SOC 2)
- ✓ Need to control key rotation
- ✓ Need detailed audit trails
- ✓ Need to grant permissions to specific roles
- ✓ Production databases, sensitive logs

**When AWS managed is okay:**
- ✓ Non-sensitive data
- ✓ Development environments
- ✓ Cost optimization is priority
- ✓ No compliance requirements

---

## Q4: How do you create a KMS key policy for service access?

**Answer:**
KMS key policies control which AWS services can use the key.

**Common service policies:**

**For S3:**
```json
{
  "Sid": "Allow S3 to use the key",
  "Effect": "Allow",
  "Principal": {
    "Service": "s3.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey"
  ],
  "Resource": "*"
}
```

**For RDS:**
```json
{
  "Sid": "Allow RDS to use the key",
  "Effect": "Allow",
  "Principal": {
    "Service": "rds.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

**For Secrets Manager:**
```json
{
  "Sid": "Allow Secrets Manager to use key",
  "Effect": "Allow",
  "Principal": {
    "Service": "secretsmanager.amazonaws.com"
  },
  "Action": [
    "kms:Decrypt",
    "kms:DescribeKey",
    "kms:GenerateDataKey"
  ],
  "Resource": "*"
}
```

**For CloudWatch Logs:**
```json
{
  "Sid": "Allow CloudWatch Logs",
  "Effect": "Allow",
  "Principal": {
    "Service": "logs.amazonaws.com"
  },
  "Action": [
    "kms:Encrypt",
    "kms:Decrypt",
    "kms:ReEncrypt*",
    "kms:GenerateDataKey*",
    "kms:CreateGrant",
    "kms:DescribeKey"
  ],
  "Resource": "*"
}
```

---

## Q5: How do you encrypt an RDS database with KMS in Terraform?

**Answer:**

```hcl
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_db_instance" "encrypted" {
  identifier            = "my-database"
  engine                = "postgres"
  engine_version        = "15.2"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  
  # ✓ Enable encryption with custom KMS key
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  
  # ✓ Additional security
  publicly_accessible = false
  backup_retention_period = 30
  
  skip_final_snapshot = false
  final_snapshot_identifier = "backup"
}
```

**Important:**
- Must be encrypted at creation time (cannot enable after)
- Use `kms_key_id = aws_kms_key.rds.arn` (full ARN)
- Cannot change key after database created
- Backups are encrypted with same key
- Replicas inherit encryption from source

---

## Q6: How do you enable KMS encryption for S3?

**Answer:**

```hcl
resource "aws_s3_bucket" "encrypted" {
  bucket = "my-bucket"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encrypted" {
  bucket = aws_s3_bucket.encrypted.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true  # Use S3 bucket key (saves cost)
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "encrypted" {
  bucket = aws_s3_bucket.encrypted.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**S3 Bucket Key:**
- When `bucket_key_enabled = true`, S3 generates a bucket-specific key
- Reduces KMS API calls (cheaper)
- Should be enabled for most use cases
- Objects still encrypted with main KMS key

---

## Q7: How do you handle KMS key rotation?

**Answer:**

**Automatic Rotation (Recommended):**
```hcl
resource "aws_kms_key" "database" {
  enable_key_rotation = true  # Auto-rotates yearly
}
```

**Check rotation status:**
```bash
aws kms get-key-rotation-status --key-id <key_id>
```

**Manual rotation (when needed):**
```bash
aws kms rotate-key --key-id <key_id>
```

**Rotation behavior:**
- AWS creates new key material
- Old material retained for decrypting existing data
- New encryptions use new material
- No downtime or re-encryption needed
- 1-year rotation cycle (annual)

**ℹ️ Important:**
- Rotation only works for customer-managed keys
- AWS-managed keys auto-rotate every 3 years
- Cannot schedule custom rotation intervals
- Use CloudTrail to audit rotations

---

## Q8: How do you monitor KMS key usage and create alarms?

**Answer:**

```hcl
resource "aws_cloudwatch_metric_alarm" "key_disabled" {
  alarm_name          = "kms-key-disabled"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "UserErrorCount"
  namespace           = "AWS/KMS"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_actions       = [aws_sns_topic.alerts.arn]
  
  dimensions = {
    KeyId = aws_kms_key.database.id
  }
}

# Topic to receive alerts
resource "aws_sns_topic" "alerts" {
  name = "kms-alerts"
}
```

**Available metrics:**
| Metric | Meaning |
|--------|---------|
| `UserErrorCount` | Failed decryption/encryption attempts |
| `ThrottledCount` | Requests rate-limited (indicates high usage) |
| `KeyState` | Key state changes |

**CloudTrail monitoring:**
```bash
# View all KMS API calls in last 24 hours
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=ResourceName,AttributeValue=<key_id> \
  --max-results 50
```

---

## Q9: What permissions do you need to use KMS keys?

**Answer:**

**Basic permissions to use KMS key:**
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:Decrypt",
    "kms:GenerateDataKey",
    "kms:DescribeKey"
  ],
  "Resource": "arn:aws:kms:us-east-1:ACCOUNT:key/KEY_ID"
}
```

**For key management:**
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:CreateKey",
    "kms:CreateAlias",
    "kms:UpdateKeyDescription",
    "kms:GetKeyPolicy",
    "kms:PutKeyPolicy"
  ],
  "Resource": "*"
}
```

**For Terraform CI/CD:**
```json
{
  "Effect": "Allow",
  "Action": [
    "kms:CreateKey",
    "kms:CreateAlias",
    "kms:DescribeKey",
    "kms:GetKeyPolicy",
    "kms:PutKeyPolicy",
    "kms:UpdateKeyDescription",
    "kms:ListAliases"
  ],
  "Resource": "*"
}
```

**Principle of least privilege:**
- Only grant needed actions
- Use ARN to restrict to specific keys
- Use conditions for time-based access
- Audit access regularly

---

## Q10: How do you encrypt Terraform state with KMS?

**Answer:**

**In S3 backend configuration:**
```hcl
terraform {
  backend "s3" {
    bucket             = "terraform-state"
    key                = "prod/terraform.tfstate"
    region             = "us-east-1"
    encrypt            = true
    dynamodb_table     = "terraform-locks"
    kms_key_id         = "arn:aws:kms:us-east-1:ACCOUNT:key/KEY_ID"
  }
}
```

**In Terraform code (for dynamic key):**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.terraform_state.arn
    }
  }
}
```

**Why encrypt state:**
- State contains sensitive data (passwords, API keys)
- Encrypts at rest in S3
- Encrypts in transit with HTTPS
- Meets compliance requirements (HIPAA, PCI-DSS)

---

## Q11: How do you handle KMS key deletion and recovery?

**Answer:**

**Safe deletion with recovery window:**
```hcl
resource "aws_kms_key" "database" {
  deletion_window_in_days = 30  # 7-30 days to recover
}
```

**Terraform destroy (schedules deletion):**
```bash
terraform destroy
# Key will be deleted after 30-day window
# Can cancel deletion with AWS Console during window
```

**Recover a key (within window):**
```bash
aws kms cancel-key-deletion --key-id <key_id>
```

**Permanently delete (after window):**
```bash
# Automatic after window expires
# Or force delete (not recommended):
aws kms schedule-key-deletion --key-id <key_id> --pending-window-in-days 7
```

**Impact of key deletion:**
- Cannot decrypt data encrypted with key
- Backups, logs, state become inaccessible
- Applications fail (cannot decrypt)
- No recovery possible after window

**Best practice:**
- Use 30-day window for critical keys
- Create alerts before deletion
- Don't delete in production without backups
- Test recovery procedures

---

## Q12: What are common KMS errors and how to troubleshoot?

**Common Errors:**

| Error | Cause | Solution |
|-------|-------|----------|
| `InvalidKeyId.KMS` | Key doesn't exist | Verify key ARN/ID exists |
| `AccessDenied` | User lacks permissions | Add KMS permissions to IAM role |
| `DisabledException` | Key is disabled | Enable key: `aws kms enable-key` |
| `ThrottlingException` | Too many API calls | Implement exponential backoff |
| `UserErrorCount high` | Many failed attempts | Check key policy, permissions |

**Debugging steps:**
```bash
# Check key exists and status
aws kms describe-key --key-id <key_id>

# Check key policy
aws kms get-key-policy --key-id <key_id> --policy-name default

# Check rotation status
aws kms get-key-rotation-status --key-id <key_id>

# List CloudTrail events
aws cloudtrail lookup-events --lookup-attributes AttributeKey=ResourceName,AttributeValue=<key_id>
```

---

## Q13: How does KMS pricing work?

**Pricing Breakdown:**

| Component | Cost | Notes |
|-----------|------|-------|
| **Customer Managed Key** | $1/month | Charged even if unused |
| **Key Requests** | $0.03 per 10,000 | Decrypt, encrypt, generate |
| **Grants** | $0.20 per grant | Temporary permissions |
| **CloudTrail** | Additional | Audit trail logging |

**Cost optimization:**
```hcl
# Use S3 bucket key (reduces API calls 99%)
bucket_key_enabled = true

# Batch operations when possible
# Fewer decrypt calls = lower cost

# Share keys across resources
# 1 key for similar data instead of many
```

**Example calculation:**
- 1 customer managed key: $1/month
- 1 million encrypt requests: $3
- 1 million decrypt requests: $3
- **Total: ~$7/month**

---

## Q14: KMS Best Practices Checklist

**✓ Do:**
- [ ] Enable automatic key rotation
- [ ] Set deletion window to 30 days
- [ ] Use customer-managed keys for sensitive data
- [ ] Implement least privilege key policies
- [ ] Enable CloudTrail for audit logging
- [ ] Use S3 bucket keys for S3 encryption
- [ ] Tag keys for organization and cost tracking
- [ ] Test key rotation procedures
- [ ] Monitor key usage with CloudWatch
- [ ] Use KMS grants for temporary access
- [ ] Encrypt state files with KMS
- [ ] Encrypt database backups

**✗ Don't:**
- [ ] Use AWS-managed keys for compliance workloads
- [ ] Share keys across unrelated services
- [ ] Delete keys without recovery window
- [ ] Store key material outside AWS
- [ ] Hardcode key IDs (use variables/data sources)
- [ ] Disable CloudTrail logging
- [ ] Grant wildcard (*) permissions
- [ ] Use short deletion windows (< 30 days)
- [ ] Forget to encrypt backups
- [ ] Rotate keys manually unless necessary

---

## Q15: KMS vs Other Encryption Options

**Comparison Table:**

| Aspect | KMS | Application-Level | TDE (Database) |
|--------|-----|-------------------|-----------------|
| **Ease of Use** | Easy (AWS integration) | Complex (code changes) | Database-specific |
| **Performance** | Minimal overhead | None | Minimal |
| **Key Management** | AWS managed | Self-managed | Self-managed |
| **Cost** | Pay per request | None | Included in license |
| **Compliance** | ✓ HIPAA, PCI, SOC 2 | Depends on code | Varies |
| **Use Case** | General AWS | Specific fields | All database data |

**When to use KMS:**
- ✓ Multi-service encryption
- ✓ Compliance requirements
- ✓ Centralized key management
- ✓ Audit trail needed

---

## Quick Reference Commands

```bash
# Create key
aws kms create-key --description "My key"

# Create alias
aws kms create-alias --alias-name alias/my-key --target-key-id <key_id>

# Encrypt data
aws kms encrypt --key-id <key_id> --plaintext "data"

# Decrypt data
aws kms decrypt --ciphertext-blob <blob>

# Enable/disable key
aws kms enable-key --key-id <key_id>
aws kms disable-key --key-id <key_id>

# List keys
aws kms list-keys

# Get key rotation status
aws kms get-key-rotation-status --key-id <key_id>

# Enable key rotation
aws kms enable-key-rotation --key-id <key_id>

# Schedule key deletion
aws kms schedule-key-deletion --key-id <key_id> --pending-window-in-days 30
```

