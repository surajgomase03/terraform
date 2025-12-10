# Module Composition — Interview Notes

## Quick Definition
Module composition is combining multiple modules to build complete, production-grade infrastructure applications.

## Q&A Format

### Q: What is module composition?
**A:** 
Assembling infrastructure from multiple focused modules:
- VPC module → Networking
- Security module → Access control
- Compute module → Servers
- Database module → Data storage
- All composed in root module

### Q: Why compose modules?
**A:** 
Benefits:
- **Separation of concerns**: Each module focused
- **Reusability**: Use across projects
- **Testability**: Test modules independently
- **Maintainability**: Clear structure
- **Scalability**: Add/remove modules easily

### Q: Module composition pattern?
**A:** 
```
Root Module (Orchestrator)
├── VPC Module (Foundation)
├── Security Module (Access control)
├── Compute Module (Servers)
├── Database Module (Data)
└── Monitoring Module (Observability)
```

Root module orchestrates; each sub-module has single responsibility.

### Q: How to compose modules?
**A:** 
```hcl
# root module (main.tf)
module "vpc" {
  source = "./modules/vpc"
  name = var.app_name
}

module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id  # Dependency
}

module "compute" {
  source = "./modules/compute"
  security_group_id = module.security.sg_id
  depends_on = [module.security]
}
```

Pass outputs as inputs for composition.

### Q: Composition dependency order?
**A:** 
Foundation first:
1. VPC (foundation)
2. Security groups (needed by everything)
3. Compute (servers)
4. Database (data layer)
5. Monitoring (observability)

Terraform auto-detects dependencies from resource references.

### Q: Explicit dependencies?
**A:** 
```hcl
module "compute" {
  source = "./modules/compute"
  subnet_ids = module.vpc.subnet_ids  # Implicit dependency
  depends_on = [module.security]  # Explicit dependency
}
```

Use `depends_on` only when implicit references insufficient.

### Q: Composition with variables?
**A:** 
```hcl
variable "instance_count" { type = number }
variable "environment" { type = string }

locals {
  config = {
    dev = { count = 1, type = "t2.micro" }
    prod = { count = 5, type = "t3.large" }
  }
  selected = local.config[var.environment]
}

module "compute" {
  source = "./modules/compute"
  instance_count = local.selected.count
  instance_type = local.selected.type
}
```

Use locals to select config per environment.

### Q: Composition outputs?
**A:** 
Root module aggregates outputs:
```hcl
output "application_url" {
  value = "http://${module.compute.alb_dns}"
}

output "database_endpoint" {
  value = module.database.endpoint
}

output "monitoring_dashboard" {
  value = module.monitoring.dashboard_url
}
```

Single source of truth for access information.

### Q: Composition scaling?
**A:** 
Add modules without changing others:
```hcl
# Add caching layer
module "cache" {
  source = "./modules/cache"
  vpc_id = module.vpc.vpc_id
}

# Add CDN
module "cdn" {
  source = "./modules/cdn"
  alb_domain = module.compute.alb_dns
}
```

Modules are independent; add as needed.

### Q: Composition testing?
**A:** 
Test each module, then composition:
```bash
# Test VPC module alone
cd modules/vpc/test && terraform apply

# Test composition
cd root && terraform plan
cd root && terraform apply
```

### Q: Composition vs monolith?
**A:** 
| Approach | Structure | Maintainability |
|----------|-----------|-----------------|
| Monolith | All in one file | Hard to understand |
| Composition | Multiple focused modules | Easy to understand |
| Layering | Tiered modules | Clear dependencies |

Composition recommended for production.

---

## Composition Workflow

```
1. Define root module inputs
2. Create local values (config selection)
3. Call VPC module (foundation)
4. Call security module (depends on VPC)
5. Call compute module (depends on security)
6. Call database module (depends on security)
7. Call monitoring (depends on all)
8. Export root outputs (aggregation)
9. Test plan
10. Apply and verify
```

---

## Key Takeaway
Module composition builds complex infrastructure from simple, reusable modules. Root module orchestrates; each module has single responsibility. Test modules independently and as a composition.
