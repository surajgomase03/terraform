# Local State — Interview Notes

## Quick Definition
Local state stores Terraform state in `terraform.tfstate` file in current working directory (default behavior, not suitable for teams).

## Q&A Format

### Q: Where is local state stored?
**A:** 
- File: `terraform.tfstate` (JSON format)
- Location: Current working directory
- Backup: `terraform.tfstate.backup` (previous version)
- Both are in working directory, not `.terraform/`

### Q: Is local state safe?
**A:** 
No, not recommended for teams:
- No encryption by default
- No backup mechanism
- Difficult to share
- Merge conflicts if multiple engineers
- Loss risk (not versioned)

### Q: When to use local state?
**A:** 
- Local development only
- Learning/testing
- Single developer projects
- Always migrate to remote for production

### Q: How to protect local state?
**A:** 
```bash
# Add to .gitignore
echo "terraform.tfstate" >> .gitignore
echo "terraform.tfstate.*" >> .gitignore

# Restrict file permissions (Linux/Mac)
chmod 600 terraform.tfstate

# For Windows: File → Properties → Security
```

### Q: Can you convert local to remote?
**A:** 
Yes, Terraform automates this:
```powershell
# Step 1: Add backend to code
terraform {
  backend "s3" {
    bucket = "my-bucket"
    key    = "terraform.tfstate"
    region = "us-east-1"
  }
}

# Step 2: Initialize
terraform init  # Asks to migrate local to S3

# Step 3: Confirm
# Local state moved to S3
```

### Q: What if I lose local state?
**A:** 
- No backup → can't recover
- Resources remain in cloud (orphaned)
- Must manually import or delete
- Prevention: Use remote state

### Q: Local state performance?
**A:** 
- Fast (file operations)
- No network latency
- Suitable for small projects
- Slower with large state files (100+ resources)

### Q: How big can local state get?
**A:** 
- Typical: 10KB-1MB per state file
- Large deployments: 5-50MB
- Size includes: resource properties, outputs, metadata
- Slower terraform operations with large files

### Q: Can you backup local state?
**A:** 
Yes, but manual:
```powershell
# Copy state file
Copy-Item terraform.tfstate "backup_$(Get-Date -f 'yyyy-MM-dd').tfstate"

# Or with Terraform
terraform state pull > backup.tfstate

# Restore
terraform state push backup.tfstate
```

### Q: Is local state ever used in production?
**A:** 
Rarely:
- Single operator environments (operations team)
- Highly secure networks (no internet access)
- Development environments
- Learning/lab scenarios

### Q: Local state and concurrency?
**A:** 
Problems:
- Two engineers run terraform apply simultaneously
- State file corruption (both write at same time)
- Merge conflicts impossible to resolve
- Solution: Remote state with locking

### Q: File permissions for local state?
**A:** 
```bash
# Linux/Mac: Make readable only to owner
chmod 600 terraform.tfstate

# Windows: Use File ACLs (not simple)
# Better: Use remote state to avoid this issue
```

---

## Local State Workflow (Dev Only)

```bash
# 1. Initialize (creates terraform.tfstate)
terraform init

# 2. Plan
terraform plan

# 3. Apply (state updated)
terraform apply

# 4. Backup (recommended)
cp terraform.tfstate backup_$(date +%s).tfstate

# 5. Destroy
terraform destroy
```

---

## Key Takeaway
Local state is convenient for single-developer projects but should be migrated to remote state immediately for any team collaboration or production work.
