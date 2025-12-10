# Drift Detection — Interview Notes

## Quick Definition
Drift occurs when actual infrastructure differs from Terraform state (manual changes, external systems, configuration drift).

## Q&A Format

### Q: What is infrastructure drift?
**A:** 
Difference between infrastructure as defined in Terraform and actual infrastructure in cloud:
- Manual changes via console
- Changes by other teams/tools
- Compliance/security updates
- External system modifications
- Expired temporary changes

### Q: How to detect drift?
**A:** 
```powershell
# Detect drift with plan
terraform plan
# Output shows differences (like code review)
# Example:
# ~ aws_security_group.allow {
#     ~ ingress: Manual rule added (not in code)
#   }
```

### Q: What causes drift?
**A:** 
Common causes:
1. Console-based changes (clicking AWS console)
2. AWS auto-scaling or managed services (tags, capacity)
3. Lambda function auto-updates
4. Security patches (by compliance team)
5. Manual operators (emergency changes)
6. Other automation tools
7. Costs-saving tools (auto-shutdown)

### Q: How to handle drift?
**A:** 
Three options:
1. **Accept drift**: Do nothing, live with difference
2. **Reconcile code**: Update Terraform to match reality
3. **Force alignment**: Run apply to override changes

### Q: Accept drift (Option 1)?
**A:** 
For changes you don't control:
```hcl
# Use lifecycle ignore_changes
resource "aws_security_group" "app" {
  lifecycle {
    ignore_changes = [
      tags["AutoScalingGroup"],  # Ignore auto-added tags
      ingress                     # Ignore rules added by other tools
    ]
  }
}

# Or ignore all changes
lifecycle {
  ignore_changes = all  # Not recommended
}
```

### Q: Reconcile code (Option 2)?
**A:** 
For intentional changes:
```hcl
# Update code to match actual infrastructure
resource "aws_security_group" "app" {
  # Add new rule added in console
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["192.168.0.0/16"]
  }
  
  # ... existing rules
}

# Verify
terraform plan  # Should show no changes
```

### Q: Force alignment (Option 3)?
**A:** 
Apply Terraform changes (risky):
```powershell
# This will remove manually-added rules
terraform apply
# Infrastructure now matches code exactly
# WARNING: May cause outages (removed rules/tags)
```

### Q: How to prevent drift?
**A:** 
Best practices:
1. **Principle**: All changes go through Terraform (no console access)
2. **Access control**: Restrict AWS console changes (IAM policies)
3. **Automation**: Use Terraform Cloud auto-apply
4. **Policies**: Use SCP (Service Control Policies) to prevent manual changes
5. **Alerts**: CloudWatch alerts on resource changes
6. **Immutable infrastructure**: Replace instead of modify

### Q: Drift detection in teams?
**A:** 
Workflow:
```
Engineer 1: terraform apply (changes infrastructure)
            ↓
Engineer 2: Manual change via console (causes drift)
            ↓
Engineer 3: terraform plan (detects drift)
            ↓
Team: Review drift, decide action
            ↓
Reconcile code or force alignment
```

### Q: Drift on different resource types?
**A:** 
| Resource | Drift Prone | Common Changes |
|----------|------------|-----------------|
| Security Group | High | Rules, tags |
| IAM Policy | Medium | Permissions |
| RDS Instance | Medium | Tags, capacity |
| S3 Bucket | Low | Versioning, encryption |
| Compute | Medium | Tags, monitoring |
| VPC | Low | Tags, endpoints |

### Q: Automated drift detection?
**A:** 
Terraform Cloud/Enterprise:
```
- Scheduled drift detection (daily)
- Automatic alerts
- Drift comparison UI
- Remediation suggestions
```

CLI approach:
```powershell
# Schedule with cron (Linux) or Task Scheduler (Windows)
0 3 * * * terraform plan -out=/tmp/drift.plan

# Check for differences
if ($lastexitcode -ne 0) { Send-Alert "Drift detected" }
```

### Q: Drift recovery?
**A:** 
Steps:
```powershell
# Step 1: Detect
terraform plan

# Step 2: Analyze changes
# Review what changed and who made changes (check CloudTrail)

# Step 3: Decide action
# Option A: Update code (reconcile)
# Option B: Revert changes (terraform apply)
# Option C: Ignore in code (lifecycle ignore_changes)

# Step 4: Document
# Why drift happened, what action taken, ticket/PR reference
```

### Q: Drift and state file?
**A:** 
Important distinction:
- **State file**: Terraform's record of last apply (can be outdated)
- **Drift**: Difference between state and actual infrastructure
- **terraform refresh**: Updates state to match current reality (deprecated)
- **terraform plan**: Detects drift by comparing state + code to actual

### Q: Can code have bugs but no drift?
**A:** 
Yes, example:
```hcl
# Code: Allow port 22 from 0.0.0.0/0 (bad security)
resource "aws_security_group" "web" {
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Insecure, but matches infrastructure
  }
}

# Result: No drift detected (both are wrong)
# But: Should be fixed in code, not called drift
```

---

## Drift Detection Workflow

```
1. terraform plan
   ↓
2. Review output for ~ (changed) and +/- (new/removed)
   ↓
3. Investigate cause (console? other tool? auto-scaling?)
   ↓
4. Decide:
   ├─ Update code to match → terraform apply (no changes)
   ├─ Revert to code → terraform apply (destroys manual changes)
   └─ Ignore in lifecycle → Add ignore_changes block
   ↓
5. Document why drift happened
   ↓
6. Implement prevention (IAM policies, alerts, automation)
```

---

## Key Takeaway
Drift is normal in cloud. Detect regularly with `terraform plan`. Decide consciously whether to reconcile code or ignore in lifecycle. Prevent drift with policy and access control.
