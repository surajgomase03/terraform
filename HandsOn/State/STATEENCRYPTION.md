# State File Encryption — Interview Notes

## Quick Definition
Encrypting state files protects sensitive data (passwords, tokens, API keys) that Terraform stores unencrypted by default.

## Q&A Format

### Q: Why encrypt state?
**A:** 
State files contain sensitive data:
- Database passwords
- API tokens
- Private keys
- SSH keys
- OAuth secrets
- Encryption keys

Unencrypted = exposed if state file leaked.

### Q: What's stored in state?
**A:** 
```hcl
# Code:
resource "aws_db_instance" "prod" {
  master_username = "admin"
  master_password = "MyP@ssw0rd123"  # EXPOSED in state file!
}

# State file stores entire resource definition (including password)
# Anyone with state access = password exposed
```

### Q: How to encrypt state (local)?
**A:** 
Local state files can't be encrypted natively:
- Files stored unencrypted in working directory
- Use OS file permissions: `chmod 600 terraform.tfstate`
- Better: Use remote state with encryption

### Q: How to encrypt state (S3 backend)?
**A:** 
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true  # Enable encryption at rest
    dynamodb_table = "terraform-locks"
  }
}
```

### Q: What encryption type (S3)?
**A:** 
Two options:
1. **SSE-S3** (Server-Side Encryption S3): AWS-managed keys (simpler)
2. **SSE-KMS** (Server-Side Encryption KMS): Customer-managed keys (stronger)

Default: SSE-S3. Recommended: SSE-KMS for compliance.

### Q: How to use KMS encryption?
**A:** 
```hcl
# Step 1: Create KMS key
resource "aws_kms_key" "terraform" {
  description             = "KMS key for Terraform state"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_alias" "terraform" {
  name          = "alias/terraform-state"
  target_key_id = aws_kms_key.terraform.key_id
}

# Step 2: Add KMS to backend config
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:123456789012:key/12345678-..."
    dynamodb_table = "terraform-locks"
  }
}

# Step 3: Re-initialize
terraform init  # S3 backend now uses KMS encryption
```

### Q: KMS vs S3-managed keys?
**A:** 
| Feature | S3-managed | KMS |
|---------|-----------|-----|
| Encryption | AES-256 | AES-256 |
| Key storage | AWS managed | Customer controlled |
| Key rotation | Auto | Optional (recommended) |
| Audit logging | Basic | CloudTrail detailed logs |
| Cost | No extra | ~$1/month |
| Compliance | Standard | HIPAA, PCI-DSS |
| Recommended | Dev | Prod, regulated |

### Q: How to prevent secrets in state?
**A:** 
Best practices:
```hcl
# AVOID: Don't store secrets in variables
variable "db_password" {
  type = string  # Will end up in state!
}

# BETTER: Use AWS Secrets Manager
resource "aws_secretsmanager_secret" "db" {
  name                    = "db-password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    username = "admin"
    password = "MyP@ssw0rd123"  # Stored in Secrets Manager, not state
  })
}

# Reference in application (not Terraform)
# Application fetches from Secrets Manager at runtime
```

### Q: Use sensitive = true?
**A:** 
Helps but doesn't prevent exposure:
```hcl
variable "db_password" {
  type      = string
  sensitive = true  # Hides from terraform output/logs
}

# Effect:
# - terraform output won't display value
# - Console logs won't show value
# BUT: Still stored unencrypted in state file!
# Solution: Still use Secrets Manager
```

### Q: Encrypt state in transit?
**A:** 
Terraform uses HTTPS automatically:
- All remote state access uses TLS
- State never transmitted unencrypted
- Verify SSL certificates

Additional security:
```
- VPC endpoints (for S3)
- Private subnets (no internet access)
- VPN/bastion hosts
```

### Q: Encrypt state in Terraform Cloud?
**A:** 
Automatic:
- State encrypted at rest (AES-256)
- Encrypted in transit (TLS)
- No manual setup required
- Access controlled via roles

### Q: Rotate encryption keys?
**A:** 
For KMS:
```hcl
# Enable automatic key rotation
resource "aws_kms_key" "terraform" {
  enable_key_rotation = true  # Auto-rotates yearly
}

# Manual rotation (re-encrypt state):
# 1. Get current state
terraform state pull > state-backup.json

# 2. Update backend config (change KMS key ID)
# 3. Re-init
terraform init

# 4. New key encrypts state on next apply
```

### Q: State backup encryption?
**A:** 
Backup should also be encrypted:
```powershell
# Backup with encryption
terraform state pull | aws s3 cp - s3://backup-bucket/state.json \
  --sse AES256

# Or with KMS
aws s3 cp state-backup.json s3://backup-bucket/ \
  --sse aws:kms \
  --sse-kms-key-id arn:aws:kms:...
```

### Q: Audit encryption usage?
**A:** 
CloudTrail logs KMS key usage:
```
KMS API calls logged:
- Decrypt (when Terraform reads state)
- Encrypt (when Terraform writes state)
- GenerateDataKey (for envelope encryption)

Check CloudTrail:
- Who accessed state (via KMS logs)
- When accessed
- Success/failure
```

### Q: Encryption performance?
**A:** 
Minimal impact:
- S3-managed: No additional latency
- KMS: <10ms additional latency (for key operations)
- Cost: KMS adds ~$0.03/request (negligible)

---

## Encryption Checklist

- [ ] Local state: Use remote state instead
- [ ] S3 backend: Enable `encrypt = true`
- [ ] KMS: Use customer-managed keys (prod)
- [ ] Sensitive vars: Use Secrets Manager (not variables)
- [ ] Mark vars: `sensitive = true`
- [ ] Backup: Also encrypt backups
- [ ] Access: Restrict S3/KMS access (IAM)
- [ ] Audit: Enable CloudTrail logging
- [ ] Rotation: Enable automatic key rotation

---

## Key Takeaway
Always encrypt state files (S3 `encrypt=true`), use KMS for production. Never store secrets in Terraform variables—use Secrets Manager. Mark sensitive outputs as `sensitive = true`.
