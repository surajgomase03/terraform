# Local Modules — Interview Notes

## Quick Definition
Local modules are reusable Terraform modules stored in your project directory (typically `./modules/` folder) for organizing and reusing infrastructure code.

## Q&A Format

### Q: What is a local module?
**A:** 
A module stored in your project:
- Source: Relative path `./modules/vpc`
- No version pinning (uses current code)
- Maintainer: Your team
- Repository: Same Git repo
- Examples: VPC, security, compute modules

### Q: Local vs public modules?
**A:** 
| Feature | Local | Public |
|---------|-------|--------|
| Location | Project directory | Terraform Registry |
| Source | `./modules/vpc` | `terraform-aws-modules/vpc/aws` |
| Version | None (current) | ~> 5.0 |
| Maintenance | Your team | Community |
| Updates | Git pull | terraform init |

### Q: Local module structure?
**A:** 
```
project-root/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── compute/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    └── database/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── README.md
```

### Q: How to organize modules?
**A:** 
By responsibility:
- `modules/vpc/` - Networking
- `modules/security/` - Security groups
- `modules/compute/` - EC2, ASG, ALB
- `modules/database/` - RDS, DynamoDB
- `modules/monitoring/` - CloudWatch
- `modules/storage/` - S3, EBS

Or by application:
- `modules/web-app/` - Entire web app
- `modules/api/` - API backend
- `modules/database/` - Shared database

### Q: How to call local module?
**A:** 
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_name = "prod-vpc"
  cidr_block = "10.0.0.0/16"
  tags = local.common_tags
}
```

Relative paths work from root module location.

### Q: Nested local modules?
**A:** 
Yes, modules can call other modules:
```hcl
# modules/networking/main.tf
module "vpc" {
  source = "../vpc"
}

module "security" {
  source = "../security"
}
```

But keep nesting shallow (2-3 levels max).

### Q: Local module versioning?
**A:** 
No version pinning:
```hcl
module "vpc" {
  source = "./modules/vpc"
  # No version attribute
}
```

Version control via Git:
- Tag releases: `v1.0.0`
- Use git submodules for shared modules
- Document module changes in CHANGELOG.md

### Q: How to version local modules (team)?
**A:** 
Option 1: Git tags
```bash
# In modules/ directory
git tag v1.0.0
git push origin v1.0.0
```

Option 2: Terraform Cloud private registry
```hcl
module "vpc" {
  source = "app.terraform.io/company/vpc/aws"
  version = "~> 1.0"
}
```

### Q: Environment-specific modules?
**A:** 
Use locals for environment config:
```hcl
locals {
  instance_config = {
    dev = "t2.micro"
    prod = "t3.large"
  }
}

module "compute" {
  source = "./modules/compute"
  instance_type = local.instance_config[var.environment]
}
```

Or separate directories:
```
environments/
├── dev/
│   └── main.tf
└── prod/
    └── main.tf
```

### Q: Local module testing?
**A:** 
Create test configuration:
```
modules/vpc/
├── main.tf
├── variables.tf
├── outputs.tf
└── test/
    └── main.tf  # Minimal test configuration
```

```bash
cd modules/vpc/test
terraform init
terraform plan
terraform apply
terraform destroy
```

### Q: Local module documentation?
**A:** 
Create README.md in each module:
```markdown
# VPC Module

## Description
Creates VPC with public/private subnets

## Usage
\`\`\`hcl
module "vpc" {
  source = "./modules/vpc"
  vpc_name = "prod-vpc"
  cidr_block = "10.0.0.0/16"
}
\`\`\`

## Inputs
- vpc_name: Name of VPC
- cidr_block: CIDR block

## Outputs
- vpc_id: ID of created VPC
- subnet_ids: IDs of subnets
```

### Q: When to extract local module?
**A:** 
Extract when:
- Resource block appears in multiple places
- Code becomes hard to understand
- Team needs to share logic
- Testing becomes difficult
- Reuse across projects needed

Don't over-engineer early.

---

## Local Module Checklist

- [ ] Clear directory structure
- [ ] One responsibility per module
- [ ] All inputs as variables
- [ ] Sensible defaults
- [ ] Clear outputs
- [ ] README.md documentation
- [ ] Tested in isolation
- [ ] No hard-coded values
- [ ] CHANGELOG.md for updates
- [ ] Git tag for versions

---

## Key Takeaway
Local modules organize your code by responsibility, making it easier to understand and maintain. Extract modules when code becomes complex or repetitive. Document with README files.
