# Root Module — Interview Notes

## Quick Definition
Root module is any Terraform configuration at the top level that contains provider blocks, resources, and module calls (usually in a directory without a parent module).

## Q&A Format

### Q: What is a root module?
**A:** 
The top-level Terraform configuration that:
- Contains `terraform {}` and `provider {}` blocks
- Calls child modules via `module {}` blocks
- Defines input variables (`variables.tf`)
- Exports outputs (`outputs.tf`)
- Contains main resource definitions

### Q: How many root modules can a project have?
**A:** 
Multiple (one per configuration instance):
- Dev environment: separate root module with dev configuration
- Prod environment: separate root module with prod configuration
- Each root module has its own state file
- Each can use different variable values

### Q: Root module vs child module?
**A:** 
| Feature | Root | Child |
|---------|------|-------|
| terraform block | Required | Optional |
| provider blocks | Defines | Inherits |
| backend config | Yes | No |
| Module calls | Yes | Usually no |
| source attribute | N/A | Required |
| version pinning | For providers | For modules |

### Q: What goes in root module?
**A:** 
```hcl
# main.tf - root module calls child modules
module "vpc" {
  source = "./modules/vpc"
  name   = var.vpc_name
}

# variables.tf - inputs to root module
variable "vpc_name" {
  type = string
}

# outputs.tf - expose outputs from modules
output "vpc_id" {
  value = module.vpc.vpc_id
}

# terraform.tfvars - variable values
vpc_name = "prod-vpc"
```

### Q: Root module best practice?
**A:** 
- Keep it thin (mostly module calls)
- Use locals for common values
- Don't create resources in root (except in simple projects)
- Orchestrate and compose modules
- Document with README.md

### Q: Can root module call other root modules?
**A:** 
No, root modules don't nest:
- Root module calls child modules
- Child modules can call other child modules (nested modules)
- Cannot create circular dependencies

### Q: How to test root module?
**A:** 
```bash
# Initialize
terraform init

# Validate syntax
terraform validate

# Preview changes
terraform plan

# Dry-run in CI/CD
terraform plan -out=tfplan
terraform show tfplan
```

### Q: Root module with multiple environments?
**A:** 
Options:
1. **Separate directories** (recommended)
   ```
   environments/dev/main.tf (root)
   environments/prod/main.tf (root)
   ```
2. **Workspace-based** (discouraged)
   ```
   terraform workspace select prod
   ```
3. **Variable-based** (ok for small projects)
   ```
   terraform apply -var-file=prod.tfvars
   ```

### Q: Root module outputs?
**A:** 
Export important values:
```hcl
output "load_balancer_url" {
  value = module.compute.alb_dns_name
}

output "database_endpoint" {
  value = module.database.endpoint
}
```

Other projects reference via `terraform_remote_state`.

### Q: Root module dependencies?
**A:** 
- VPC module (foundation)
- Security module (depends on VPC)
- Compute module (depends on Security)
- Database module (depends on Security)
- Monitoring module (depends on everything)

Use explicit `depends_on` if implicit references don't exist.

---

## Key Takeaway
Root module is the entry point that orchestrates child modules. Keep it clean by delegating resource creation to focused child modules.
