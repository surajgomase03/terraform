# Public Registry Modules — Interview Notes

## Quick Definition
Public Registry Modules are pre-built, community-maintained modules available on Terraform Registry (https://registry.terraform.io/) for common infrastructure patterns.

## Q&A Format

### Q: What is Terraform Registry?
**A:** 
Central repository at https://registry.terraform.io/:
- Thousands of modules
- Providers
- Policy libraries
- Maintained by HashiCorp, AWS, community
- Free to use
- Can publish your own

### Q: How to find modules?
**A:** 
1. Visit https://registry.terraform.io/
2. Filter by provider (AWS, Azure, GCP)
3. Sort by rating/downloads
4. Read documentation
5. Check maintenance (recent updates?)
6. Review GitHub repo (issues, PRs)

### Q: How to use public module?
**A:** 
```hcl
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "my-vpc"
  cidr = "10.0.0.0/16"
}
```

Source format: `<namespace>/<name>/<provider>`

### Q: Popular AWS modules?
**A:** 
- vpc/aws: VPC, subnets, NAT, VPN
- security-group/aws: Security groups
- rds/aws: RDS databases
- alb/aws: Application Load Balancer
- autoscaling/aws: Auto Scaling Groups
- sns/aws: SNS topics
- s3/aws: S3 buckets

### Q: Advantages of public modules?
**A:** 
- Battle-tested (used by many)
- Maintained actively
- Best practices built-in
- Security updates
- Saves development time
- Community-driven improvements

### Q: Disadvantages of public modules?
**A:** 
- External dependency
- May not fit exact use case
- Version upgrades can be breaking
- Documentation may be incomplete
- Requires understanding module internals

### Q: How to version public modules?
**A:** 
```hcl
# Always pin version
version = "~> 5.0"   # Safe (allows 5.x)
version = "= 5.0.0"  # Strict (exact only)
version = ">= 5.0"   # Risky (too permissive)
```

Recommended: `~> MAJOR.MINOR` (pessimistic operator)

### Q: Module versioning upgrade process?
**A:** 
```hcl
# Step 1: Check current version
terraform version -json | grep terraform

# Step 2: Update version in code
version = "~> 6.0"  # was ~> 5.0

# Step 3: Re-initialize
terraform init

# Step 4: Review changes
terraform plan

# Step 5: Test and apply
terraform apply
```

### Q: Public module examples?
**A:** 
```hcl
# VPC with 3 AZs, public/private subnets, NAT
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "prod-vpc"
  cidr = "10.0.0.0/16"
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  enable_nat_gateway = true
}

# RDS with automated backups and monitoring
module "rds" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"
  
  identifier = "prod-postgres"
  engine = "postgres"
  instance_class = "db.t3.micro"
  allocated_storage = 20
  backup_retention_period = 30
  enabled_cloudwatch_logs_exports = ["postgresql"]
}
```

### Q: Can you modify public module?
**A:** 
Not directly recommended:
- Use module inputs for customization
- Fork to GitHub if major changes needed
- Contribute back to original if valuable

Better: Create wrapper module:
```hcl
# modules/custom-vpc/main.tf
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  # Custom defaults
  name = var.vpc_name
  cidr = var.vpc_cidr
  enable_nat_gateway = var.enable_nat
  
  # Pass-through
  azs = var.azs
}
```

### Q: Private Registry (for teams)?
**A:** 
Terraform Cloud/Enterprise:
- Publish internal modules
- Version control
- Access control
- Usage analytics

Better than public for company standards.

---

## Public Module Checklist

- [ ] Search Registry for existing module
- [ ] Check module rating and downloads
- [ ] Review documentation
- [ ] Check GitHub for active maintenance
- [ ] Verify provider compatibility
- [ ] Pin version with ~> MAJOR.MINOR
- [ ] Test in dev environment
- [ ] Review outputs needed
- [ ] Document module usage
- [ ] Plan for version upgrades

---

## Key Takeaway
Public Registry modules save time and promote best practices. Always pin versions with pessimistic constraints. Review module quality before adopting. Contribute improvements back to community when possible.
