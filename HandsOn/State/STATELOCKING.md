# State Locking — Interview Notes

## Quick Definition
State locking prevents concurrent modifications to state by allowing only one terraform apply at a time, preventing corruption and conflicts.

## Q&A Format

### Q: Why is state locking needed?
**A:** 
Prevents state corruption when multiple engineers run terraform apply simultaneously:
- Without lock: State file written by both processes (corruption)
- With lock: First process gets lock, second waits or fails
- DynamoDB or Consul holds the lock

### Q: How does state locking work?
**A:** 
```
Engineer A runs: terraform apply
  → Writes lock to DynamoDB (LockID = state file key)
  → Makes infrastructure changes
  → Deletes lock from DynamoDB
  → Releases state

Engineer B runs: terraform apply (during A's apply)
  → Tries to acquire lock
  → Lock exists (held by A)
  → Waits (default timeout: 0 = immediate fail)
  → Fails with error message
```

### Q: When is state locked?
**A:** 
- During: terraform apply (writing changes)
- During: terraform destroy
- During: terraform state operations (mv, rm, etc.)
- NOT during: terraform plan (read-only)
- NOT during: terraform init
- NOT during: terraform validate

### Q: What backend supports locking?
**A:** 
| Backend | Locking | Notes |
|---------|---------|-------|
| S3 | DynamoDB required | Most common |
| Terraform Cloud | Built-in | Automatic |
| Azure Storage | Built-in | Automatic |
| Consul | Built-in | For on-prem |
| Local | Not supported | Use remote state |
| HTTP | Varies | Implementation-dependent |

### Q: How to set up DynamoDB for locking?
**A:** 
```hcl
# Step 1: Create DynamoDB table
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  attribute {
    name = "LockID"
    type = "S"  # String type required
  }
}

# Step 2: Reference in backend
terraform {
  backend "s3" {
    bucket         = "my-state"
    key            = "prod/tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"  # Enable locking
  }
}
```

### Q: What if lock is stuck?
**A:** 
Happens when process crashes or network fails:
```powershell
# Step 1: Identify stuck lock
terraform apply  # Shows lock ID and who/when created

# Step 2: Manual unlock (last resort)
terraform force-unlock <LOCK_ID>

# Step 3: Investigate what happened
# Check CloudWatch Logs or console
# Run terraform plan to verify state

# Prevention: Use -lock-timeout to wait
terraform apply -lock-timeout=10m  # Wait 10 minutes for lock
```

### Q: Lock timeout behavior?
**A:** 
```powershell
# Apply waits for lock (infinite)
terraform apply

# Apply waits 5 minutes, then fails
terraform apply -lock-timeout=5m

# Apply fails immediately if lock exists (risky)
terraform apply -lock=false -lock-timeout=0s
```

### Q: Can you disable locking?
**A:** 
Yes, but risky:
```powershell
# Run without acquiring lock
terraform apply -lock=false

# Use case: Read-only operations, emergencies
# Never use for: Normal applies, writes to state
```

### Q: Lock cost?
**A:** 
DynamoDB (PAY_PER_REQUEST):
- ~$0.25/million write units
- Terraform uses 1 write (acquire) + 1 write (release)
- Cost: Negligible (<$1/month for active projects)

### Q: How to test locking?
**A:** 
```powershell
# Terminal 1: Start apply (locks state)
terraform apply -auto-approve

# Terminal 2: Try to apply (blocks until first finishes)
terraform apply -auto-approve  # Waits for lock

# Terminal 2: Kill process to test force-unlock
terraform force-unlock <LOCK_ID>
```

### Q: Can you lock/unlock manually?
**A:** 
Not recommended, but possible:
```powershell
# Check current lock
aws dynamodb scan \
  --table-name terraform-locks \
  --region us-east-1

# Manual unlock (dangerous)
aws dynamodb delete-item \
  --table-name terraform-locks \
  --key '{"LockID": {"S": "prod/terraform.tfstate"}}'
```

### Q: Locking in Terraform Cloud?
**A:** 
Automatic and always enabled:
- No manual setup required
- No DynamoDB table needed
- Terraform Cloud manages locking
- Can be disabled per-apply (not recommended)

---

## State Lock Troubleshooting

| Problem | Cause | Solution |
|---------|-------|----------|
| Lock timeout | Long-running apply | Increase -lock-timeout or wait for process |
| Stuck lock | Crashed process | terraform force-unlock <ID> |
| Permission denied | IAM policy | Check DynamoDB permissions |
| Lock table missing | Not created | Create DynamoDB table first |
| Lock in Terraform Cloud | Unknown | Contact HashiCorp support |

---

## Key Takeaway
State locking is essential for team environments. Use DynamoDB for S3 backend, or Terraform Cloud for automatic locking. Always wait for locks instead of forcing unlock.
