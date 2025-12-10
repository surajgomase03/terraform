# Version Pinning — Interview Notes

## Quick Definition
Version pinning is constraining Terraform, providers, and modules to specific versions to ensure consistency and prevent breaking changes.

## Q&A Format

### Q: Why pin versions?
**A:** 
Prevent breaking changes:
- Major version updates = breaking changes
- Unpinned = automatic upgrades
- Upgrades can break code
- Pinning = explicit control

Example: AWS provider 4→5 major change:
- Old: `resource "aws_instance"...`
- New: Requires different syntax
- Unpinned: Automatic upgrade breaks plan
- Pinned: Control upgrade timing

### Q: Terraform version pinning?
**A:** 
```hcl
terraform {
  required_version = "~> 1.5"  # Allow 1.5.x
}
```

Versions:
- `>= 1.5, < 2.0`: Version 1.5 or higher, less than 2.0
- `~> 1.5`: Pessimistic (allows 1.5.x, not 1.4.x or 2.0.x)
- `= 1.5.0`: Exact version only (strict)

### Q: Provider version pinning?
**A:** 
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow 5.x, not 4.x or 6.x
    }
  }
}
```

Example versions:
- `~> 5.0`: >= 5.0.0, < 6.0.0 (RECOMMENDED)
- `>= 5.0`: >= 5.0.0 (too permissive)
- `= 5.23.0`: Exact (too strict)

### Q: Module version pinning (public registry)?
**A:** 
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"  # Allow 5.x
}
```

For local modules:
```hcl
module "vpc" {
  source = "./modules/vpc"  # No version
}
```

### Q: Pessimistic operator (~>)?
**A:** 
Allows minor/patch updates, blocks major:
- `~> 5.0` = `>= 5.0.0, < 6.0.0` (RECOMMENDED)
- `~> 5.23` = `>= 5.23.0, < 5.24.0` (too restrictive)

Why recommended:
- Automatic security patches
- Blocks breaking major changes
- Sweet spot for stability

### Q: Version upgrade workflow?
**A:** 
```bash
# Step 1: Check current version
terraform version

# Step 2: Update version in code
# Change: version = "~> 4.0"
# To:     version = "~> 5.0"

# Step 3: Re-initialize
terraform init

# Step 4: Review changes
terraform plan

# Step 5: Test (run in dev first)
terraform apply

# Step 6: Merge to main
git commit -m "Upgrade AWS provider to 5.0"
git push
```

### Q: .terraform.lock.hcl file?
**A:** 
Auto-created lock file:
- Tracks exact versions used
- Ensures team uses same versions
- Commit to version control
- Prevents version skew

Content:
```hcl
terraform_required_version = "1.5.0"
provider "registry.terraform.io/hashicorp/aws" {
  version = "5.23.0"
}
```

### Q: Version constraint operators?
**A:** 
| Operator | Meaning | Example | Allows |
|----------|---------|---------|---------|
| = | Exact | = 5.0.0 | 5.0.0 only |
| != | Exclude | != 5.0.0 | Anything but 5.0.0 |
| > | Greater | > 5.0.0 | 5.0.1, 5.1.0, 6.0.0 |
| >= | Greater/equal | >= 5.0.0 | 5.0.0+ |
| < | Less | < 6.0.0 | 5.x.x |
| <= | Less/equal | <= 5.0.0 | Up to 5.0.0 |
| ~> | Pessimistic | ~> 5.0 | 5.0+ < 6.0 |

### Q: Version mismatch error?
**A:** 
```
Error: Failed to query available provider packages
  provider.aws: no matching version found
  constraint: ~> 5.0
```

Solution:
- Relax constraint: `~> 5.0` → `>= 5.0`
- Check provider exists for that version
- Update to supported version

### Q: Team version consistency?
**A:** 
Use lock file (committed to Git):
```bash
# Someone upgrades
terraform init  # Creates .terraform.lock.hcl

# Team syncs
git pull
terraform init  # Uses locked versions
```

Lock file ensures everyone uses same versions.

### Q: Breaking changes in versions?
**A:** 
Review changelog before upgrading:
```bash
# AWS provider 4→5 example
# v4.x: resource "aws_security_group_rule"
# v5.x: resource "aws_vpc_security_group_ingress_rule" (NEW)

# Upgrade checklist:
# 1. Read provider changelog
# 2. Run terraform plan
# 3. Review resource changes
# 4. Test in dev
# 5. Document changes
# 6. Merge to prod
```

### Q: Version pinning best practices?
**A:** 
- ✓ Use pessimistic operator (~>)
- ✓ Pin major version only (~> 5.0)
- ✓ Commit lock file to Git
- ✓ Review updates monthly
- ✓ Test before upgrading major
- ✗ Never = (too restrictive)
- ✗ Never ">= 1.0" (too permissive)
- ✗ Skip security patches

---

## Version Pinning Checklist

- [ ] Terraform version pinned
- [ ] Provider versions pinned (use ~>)
- [ ] Module versions pinned (for public)
- [ ] .terraform.lock.hcl committed
- [ ] Version constraints documented
- [ ] Upgrade procedure documented
- [ ] Breaking changes reviewed
- [ ] Testing plan before upgrades
- [ ] Lock file in version control
- [ ] Regular update schedule

---

## Common Version Patterns

**Development**
```hcl
required_version = "~> 1.5"
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"  # Allow patch updates
  }
}
```

**Production**
```hcl
required_version = ">= 1.5, < 2.0"
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = "~> 5.0"  # Same, but tested
  }
}
```

**Conservative**
```hcl
required_version = ">= 1.5.0, < 1.6"
required_providers {
  aws = {
    source  = "hashicorp/aws"
    version = ">= 5.20, < 5.21"  # Strict updates
  }
}
```

---

## Key Takeaway
Use pessimistic operator (~> MAJOR.MINOR) to allow patches while blocking breaking changes. Commit lock file to Git. Review and test before major upgrades. Document version policy for team.
