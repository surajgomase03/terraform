# Remote State — Interview Notes

## Quick Definition
Remote state stores Terraform state files on backend servers (S3, Terraform Cloud, Azure Storage) instead of locally, enabling team collaboration and preventing state conflicts.

## Q&A Format

### Q: Why use remote state?
**A:** 
- Team collaboration (multiple engineers)
- Consistent state across deployments
- Reduced risk of state loss
- Automated backups and versioning
- Access control and audit logging

### Q: Common remote backends?
**A:** 
- S3 (AWS, most popular)
- Azure Storage (Azure)
- Google Cloud Storage (GCP)
- Terraform Cloud/Enterprise
- Consul
- HTTP
- Local (fallback)

### Q: How to migrate to remote state?
**A:** 
```hcl
# Step 1: Add backend block to main.tf
terraform {
  backend "s3" {
    bucket = "my-bucket"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

# Step 2: Run
terraform init  # Will ask to migrate state

# Step 3: Confirm migration
# Your local state is now remote
```

### Q: What's terraform_remote_state?
**A:** 
Data source to reference outputs from other Terraform modules/workspaces:
```hcl
data "terraform_remote_state" "prod" {
  backend = "s3"
  config = {
    bucket = "my-bucket"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}

# Use outputs from prod state
resource "aws_instance" "app" {
  security_groups = [data.terraform_remote_state.prod.outputs.sg_id]
}
```

### Q: Backend configuration options?
**A:** 
```hcl
terraform {
  backend "s3" {
    bucket         = "name"          # Required
    key            = "path/to/state" # Required
    region         = "us-east-1"     # Required for S3
    encrypt        = true            # Encrypt at rest
    dynamodb_table = "locks"         # State locking
  }
}
```

### Q: Can you change backends?
**A:** 
Yes, Terraform will prompt to migrate:
```powershell
# Add new backend block to code
terraform init  # Detects backend change, offers migration
# Confirm migration
```

### Q: What about secrets in remote state?
**A:** 
- Encrypted at rest (enable `encrypt = true`)
- Encrypted in transit (HTTPS)
- Restrict access (IAM policies, bucket policies)
- Use sensitive = true on variables
- Better: Use AWS Secrets Manager instead

### Q: S3 backend cost?
**A:** 
- Storage: ~$0.023/GB/month
- Requests: $0.0004/1000 GET, $0.005/1000 PUT
- DynamoDB: Pay-per-request (~$1.25/million writes)
- Total: Usually <$5/month for small deployments

### Q: How to set backend in CI/CD?
**A:** 
Use backend config files or flags:
```powershell
terraform init \
  -backend-config="bucket=my-bucket" \
  -backend-config="key=prod/tfstate" \
  -backend-config="region=us-east-1"
```

### Q: Backup strategy for remote state?
**A:** 
- S3 versioning (automatic)
- Lifecycle policies (archive old versions)
- Separate backup bucket
- Cross-region replication
- Regular `terraform state pull` backups

---

## Key Takeaway
Remote state is essential for team collaboration. Use S3 + DynamoDB for AWS, or Terraform Cloud for simpler setup.
