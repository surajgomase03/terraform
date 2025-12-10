# Terraform State Commands — Interview Notes

## Quick Command Reference

### STATE LISTING & INSPECTION

**terraform state list** — List all resources in state
```
Usage: terraform state list [pattern]
terraform state list                    # All resources
terraform state list aws_instance.*     # Filter pattern
terraform state list 'module.vpc.*'     # Module resources
```

**terraform state show** — Show resource details
```
Usage: terraform state show <resource>
terraform state show aws_instance.web       # Show resource
terraform state show 'aws_instance.web[0]'  # Indexed
terraform state show 'module.vpc.aws_vpc.main'
```

**terraform state pull** — Export entire state
```
Usage: terraform state pull
terraform state pull > backup.tfstate        # Save backup
terraform state pull | jq '.resources[0]'    # View parsed
```

---

### STATE MODIFICATION

**terraform state mv** — Move/rename resource
```
Usage: terraform state mv <source> <destination>
terraform state mv aws_instance.old aws_instance.new
terraform state mv aws_instance.web 'module.app.aws_instance.web'
terraform state mv 'aws_instance.web[0]' 'aws_instance.web[1]'
```

**terraform state rm** — Remove resource from state
```
Usage: terraform state rm <resource>
terraform state rm aws_instance.web         # Remove resource
terraform state rm 'aws_instance.web[0]'    # Indexed
terraform state rm 'module.old.*'           # Wildcard
```

**terraform state push** — Replace state (dangerous!)
```
Usage: terraform state push <file>
terraform state push backup.tfstate             # Restore backup
terraform state push backup.tfstate -force      # Remote state
WARNING: Only for disaster recovery
```

---

### RESOURCE LIFECYCLE CONTROL

**terraform taint** — Mark for replacement
```
Usage: terraform taint <resource>
terraform taint aws_instance.web              # Mark for recreation
terraform taint 'aws_instance.web[0]'         # Indexed
Effect: Next apply will destroy and recreate
```

**terraform untaint** — Unmark for replacement
```
Usage: terraform untaint <resource>
terraform untaint aws_instance.web            # Remove taint
Effect: Next apply won't recreate
```

**terraform import** — Add external resource to state
```
Usage: terraform import <resource> <id>
terraform import aws_instance.web i-0123456789abcdef0
terraform import aws_s3_bucket.data my-bucket
terraform import aws_security_group.allow sg-0123456
Prerequisites:
1. Define resource in code (empty body)
2. Know resource ID from cloud provider
3. Run import
4. Configure resource properties
```

---

### PROVIDER MANAGEMENT

**terraform state replace-provider** — Switch provider
```
Usage: terraform state replace-provider <old> <new>
terraform state replace-provider \
  'registry.terraform.io/-/aws' \
  'registry.terraform.io/hashicorp/aws'
Effect: All resources switch to new provider
```

---

## Command OPTIONS (All Commands)

```
-lock=true|false        Lock state during operation (default: true)
-lock-timeout=5m        Wait time for lock (default: 0s = fail immediately)
-backup=<path>          Backup before modification
-input=false            Non-interactive mode
```

---

## QUICK DECISION FLOWCHART

```
Want to modify resources?
├─ Rename in code? 
│  └─ terraform state mv (then update code)
├─ Stop managing? 
│  └─ terraform state rm (or use lifecycle prevent_destroy)
├─ Force recreation? 
│  └─ terraform taint
├─ Add existing resource? 
│  └─ terraform import
├─ See resource details? 
│  └─ terraform state show
├─ Backup state? 
│  └─ terraform state pull > backup.tfstate
└─ Restore from backup? 
   └─ terraform state push backup.tfstate -force
```

---

## COMMON WORKFLOWS

### Workflow 1: Rename Resource
```powershell
# Step 1: Rename in state
terraform state mv aws_instance.old aws_instance.new

# Step 2: Update code
# Change resource "aws_instance" "old" to "new"

# Step 3: Verify
terraform plan  # Should show no changes
terraform apply
```

### Workflow 2: Import Existing Resource
```powershell
# Step 1: Get resource ID from AWS
aws ec2 describe-instances --query 'Reservations[0].Instances[0].InstanceId'
# Output: i-0123456789abcdef0

# Step 2: Add to code
resource "aws_instance" "web" {
  # Empty body
}

# Step 3: Import
terraform import aws_instance.web i-0123456789abcdef0

# Step 4: Configure resource
resource "aws_instance" "web" {
  ami           = "ami-0c123456"
  instance_type = "t2.micro"
  tags          = { Name = "web" }
}

# Step 5: Verify
terraform plan  # No changes = success
```

### Workflow 3: Force Replacement
```powershell
# Step 1: Taint resource
terraform taint aws_instance.web

# Step 2: Review what will happen
terraform plan  # Shows -/+ (destroy/create)

# Step 3: Apply
terraform apply -auto-approve

# Or untaint if you changed your mind
terraform untaint aws_instance.web
```

### Workflow 4: Backup and Restore
```powershell
# Backup
terraform state pull > state_$(Get-Date -f 'yyyy-MM-dd').tfstate

# Later: Restore
terraform state push state_2025-12-11.tfstate -force
terraform apply  # Verify state restored correctly
```

---

## WHEN TO USE EACH COMMAND

| Command | Use Case | Risk | Frequency |
|---------|----------|------|-----------|
| state list | Inspect resources | None | Often |
| state show | View resource properties | None | Often |
| state pull | Backup state | Low | Weekly |
| state mv | Rename resource | Medium | Rarely |
| state rm | Stop managing | High | Rarely |
| state push | Restore from backup | Critical | Emergency |
| taint | Force recreation | Low | Occasionally |
| untaint | Undo taint | None | Occasionally |
| import | Add external resource | Medium | During migration |

---

## KEY SAFETY RULES

1. **Always backup before state push**
   ```
   terraform state pull > backup.tfstate
   ```

2. **Never use state rm without plan**
   ```
   terraform state rm resource
   terraform plan  # Verify it shows destroy
   ```

3. **Document why state operations were needed**
   ```
   # State moved due to module refactoring (PR #123)
   terraform state mv old.resource new.resource
   ```

4. **Never use -lock=false unless necessary**
   ```
   terraform apply  # Safe (uses lock)
   terraform apply -lock=false  # Risky
   ```

5. **Verify with terraform plan after state changes**
   ```
   terraform state mv old new
   # Update code to match
   terraform plan  # Verify no unexpected changes
   ```

---

## ERROR HANDLING

| Error | Cause | Solution |
|-------|-------|----------|
| Resource not found | Wrong resource address | terraform state list (find correct name) |
| Lock timeout | State locked by other process | Wait or terraform force-unlock <ID> |
| Permission denied | IAM issue | Check backend permissions |
| State corrupted | File corruption | terraform state push backup.tfstate -force |
| Import fails | Resource ID wrong | Verify ID from cloud provider |

---

## Key Takeaway
Master state commands for safe refactoring and emergency recovery. Always backup before state push. Use plan verification after state operations.
