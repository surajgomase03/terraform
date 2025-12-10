# State Manipulation — Interview Notes

## Quick Definition
State manipulation commands allow direct editing/management of state without infrastructure changes (dangerous, use as last resort).

## Q&A Format

### Q: What is terraform state command?
**A:** 
Group of commands for direct state file manipulation:
- List resources
- Show resource details
- Move resources (rename)
- Remove resources
- Taint/untaint resources
- Replace providers
- Import external resources

### Q: When to use state manipulation?
**A:** 
Only as last resort:
- Refactoring resource names (terraform state mv)
- Removing resource from management (terraform state rm)
- Tainting resource for recreation (terraform taint)
- Importing existing resources (terraform import)
- Fixing state corruption

### Q: terraform state list command?
**A:** 
```powershell
# List all resources
terraform state list

# List resources matching pattern
terraform state list 'aws_instance.*'
terraform state list 'module.vpc.*'

# Output:
# aws_instance.web[0]
# aws_instance.web[1]
# aws_security_group.allow
# module.vpc.aws_vpc.main
```

### Q: terraform state show command?
**A:** 
```powershell
# Show single resource
terraform state show aws_instance.web

# Show indexed resource
terraform state show 'aws_instance.web[0]'

# Output: JSON-like format with all properties
resource "aws_instance" "web" {
  ami           = "ami-0c123456"
  instance_type = "t2.micro"
  tags          = {"Name" = "web-server"}
}
```

### Q: terraform state mv command?
**A:** 
Rename/move resource in state (without recreation):
```powershell
# Rename resource
terraform state mv aws_instance.old aws_instance.new
# Update code to match, then terraform apply (no changes)

# Move to module
terraform state mv aws_instance.web 'module.app.aws_instance.web'

# Swap resources (for blue-green)
terraform state mv aws_instance.blue aws_instance.temp
terraform state mv aws_instance.green aws_instance.blue
terraform state mv aws_instance.temp aws_instance.green
```

### Q: terraform state rm command?
**A:** 
Remove resource from state (keeps cloud resource):
```powershell
# Remove single resource
terraform state rm aws_instance.web

# Remove indexed resource
terraform state rm 'aws_instance.web[0]'

# Remove all in module
terraform state rm 'module.old.*'

# Effect: terraform destroy thinks resource already gone
# Result: Resource remains in AWS (orphaned)
```

### Q: When to use state rm?
**A:** 
- Stop managing resource in Terraform (keep in AWS)
- Example: DB that's become critical, stop changing it
- Example: External system took over resource management
- Not recommended: Use lifecycle { prevent_destroy = true } instead

### Q: terraform state pull command?
**A:** 
Export state to stdout (for backup/inspection):
```powershell
# Pull state to file
terraform state pull > backup.tfstate

# Pull and inspect
terraform state pull | jq '.resources[0]'

# Use case: Backup, inspection, auditing, debugging
```

### Q: terraform state push command?
**A:** 
Replace state file (dangerous!):
```powershell
# Restore from backup
terraform state push backup.tfstate -force

# For remote state, requires -force flag
# WARNING: This overwrites current state
# Only use for disaster recovery
```

### Q: terraform taint command?
**A:** 
Mark resource for recreation:
```powershell
# Taint resource
terraform taint aws_instance.web

# Effect: Next terraform apply will destroy and recreate
# Use case: Force replacement, rotate credentials, update without code change

# Verify taint
terraform state show aws_instance.web  # Shows tainted
```

### Q: terraform untaint command?
**A:** 
Remove taint marker:
```powershell
# Untaint resource
terraform untaint aws_instance.web

# Effect: Next apply won't recreate
# Use case: Undo accidental taint
```

### Q: terraform state replace-provider command?
**A:** 
Switch provider for resources:
```powershell
# Migrate from old provider to new
terraform state replace-provider \
  'registry.terraform.io/-/aws' \
  'registry.terraform.io/hashicorp/aws'

# Use case: Provider namespace change, provider split
```

### Q: terraform import command?
**A:** 
Add existing resource to state:
```powershell
# Step 1: Define resource in code (empty body)
resource "aws_instance" "web" {
  # Empty - will be populated by import
}

# Step 2: Import existing instance
terraform import aws_instance.web i-0123456789abcdef0

# Step 3: Add properties to match actual resource
resource "aws_instance" "web" {
  ami           = "ami-0c123456"
  instance_type = "t2.micro"
  # ... other properties
}

# Step 4: Verify
terraform plan  # Should show no changes
```

### Q: State manipulation risks?
**A:** 
- State becomes out-of-sync with code
- terraform plan may not reflect reality
- Team confusion (state doesn't match assumptions)
- Difficult to troubleshoot later
- Always document why state manipulation was needed

### Q: How to avoid state manipulation?
**A:** 
- Use proper module structure (no refactoring needed)
- Use lifecycle { prevent_destroy = true } (instead of rm)
- Use for_each/count properly (avoid mv)
- Import during initial project setup
- Plan refactoring in team (discuss before state mv)

---

## Common State Manipulation Scenarios

| Scenario | Command | Risk |
|----------|---------|------|
| Rename resource | terraform state mv | Medium (code must change) |
| Stop managing | terraform state rm | High (orphaned resource) |
| Recreate resource | terraform taint | Low (clean replacement) |
| Undo mistake | terraform untaint | None |
| Add external resource | terraform import | Medium (must configure) |

---

## Key Takeaway
State manipulation is powerful but dangerous. Prefer code changes and lifecycle options. Use state manipulation only when necessary, and always backup state first.
