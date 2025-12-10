# Terraform Modules — Best Practices Comprehensive Guide

## 1. MODULE DESIGN PRINCIPLES

### 1.1 Single Responsibility Principle (SRP)
**Each module should do one thing well.**

```hcl
# ✓ GOOD: Single responsibility
module "vpc" {
  source = "./modules/vpc"
  # Only creates VPC, subnets, IGW
}

module "security" {
  source = "./modules/security"
  # Only creates security groups
}

# ✗ BAD: Mixed responsibilities
module "everything" {
  source = "./modules/app"
  # Creates VPC, security groups, compute, database
}
```

Benefits:
- Easier to test
- Easier to maintain
- Easier to reuse
- Easier to understand

### 1.2 Interface Clarity
**Clear input/output contracts.**

```hcl
# ✓ GOOD: Clear contract
variable "vpc_name" {
  type        = string
  description = "Name for VPC"
}

output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID for reference"
}

# ✗ BAD: Unclear inputs
variable "config" {
  type    = any  # Too permissive
  default = {}
}
```

Rules:
- Document every input variable
- Provide sensible defaults
- Validate inputs
- Export only necessary outputs
- Hide implementation details

### 1.3 Composition Over Inheritance
**Build complex infrastructure from simple modules.**

```hcl
# ✓ GOOD: Composition
module "networking" {
  source = "./modules/vpc"
}

module "access_control" {
  source    = "./modules/security"
  vpc_id    = module.networking.vpc_id
}

# ✗ BAD: Trying to inherit (not applicable in Terraform)
```

---

## 2. MODULE STRUCTURE AND ORGANIZATION

### 2.1 Directory Layout
**Consistent, clear organization.**

```
project-root/
├── README.md
├── main.tf              # Root module orchestration
├── variables.tf         # Root module inputs
├── outputs.tf           # Root module outputs
├── terraform.tfvars     # Root module values
├── .gitignore
├── .terraform.lock.hcl
├── modules/             # All child modules
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── security/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   └── README.md
│   └── database/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── README.md
└── environments/        # Environment-specific configs
    ├── dev/
    │   ├── main.tf
    │   └── terraform.tfvars
    ├── staging/
    │   ├── main.tf
    │   └── terraform.tfvars
    └── prod/
        ├── main.tf
        └── terraform.tfvars
```

### 2.2 File Organization within Modules
**Consistent file structure for each module.**

```
modules/vpc/
├── main.tf              # Resource definitions
├── variables.tf         # Input variables (sorted by importance)
├── outputs.tf           # Output values (alphabetical)
├── locals.tf            # Derived values (optional)
├── data.tf              # Data sources (optional)
├── versions.tf          # Provider versions (optional)
└── README.md            # Usage documentation
```

---

## 3. INPUT VARIABLES BEST PRACTICES

### 3.1 Variable Declaration
**Clear, well-documented variables.**

```hcl
# ✓ GOOD: Complete variable documentation
variable "instance_count" {
  type        = number
  description = "Number of application instances to create"
  default     = 2
  
  validation {
    condition     = var.instance_count > 0 && var.instance_count <= 10
    error_message = "Instance count must be between 1 and 10."
  }
}

# ✗ BAD: Minimal documentation
variable "count" {
  type    = number
  default = 2
}
```

Rules:
- Always include `type`
- Always include `description`
- Provide sensible defaults
- Add validation when possible
- Order by importance (required first)

### 3.2 Variable Naming
**Descriptive, consistent naming.**

```hcl
# ✓ GOOD
variable "database_engine"
variable "vpc_cidr_block"
variable "enable_monitoring"
variable "instance_type"

# ✗ BAD
variable "db_eng"           # Too abbreviated
variable "vpc_cidr"         # Inconsistent
variable "monitor"          # Unclear
variable "itype"            # Cryptic
```

Guidelines:
- Descriptive names (no abbreviations unless standard)
- Use snake_case
- Match resource property names when possible
- Booleans start with `enable_`, `is_`, or `has_`

### 3.3 Sensible Defaults
**Defaults for common values.**

```hcl
# ✓ GOOD: Sensible defaults
variable "instance_type" {
  default = "t3.micro"  # Works for dev/test
}

variable "backup_retention" {
  default = 7  # Standard retention
}

# ✗ BAD: No defaults, forces caller to specify
variable "instance_type" {
  # No default - requires caller config
}
```

---

## 4. OUTPUTS BEST PRACTICES

### 4.1 Output Design
**Export essential information only.**

```hcl
# ✓ GOOD: Essential outputs
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID for subnet references"
}

output "instance_ids" {
  value       = aws_instance.app[*].id
  description = "IDs of application instances"
}

# ✗ BAD: Over-exporting implementation details
output "vpc_id"
output "vpc_arn"
output "vpc_owner_id"
output "vpc_enable_dns_hostnames"
# ... 20 more outputs
```

Rules:
- Export only information needed by parent module
- Hide implementation details
- Document each output
- Use `sensitive = true` for passwords/tokens

### 4.2 Output Naming
**Consistent naming (alphabetical order).**

```hcl
# ✓ GOOD: Alphabetical, descriptive
output "database_endpoint" { ... }
output "instance_ids" { ... }
output "security_group_id" { ... }

# ✗ BAD: Random order
output "sg_id" { ... }
output "db_endpoint" { ... }
output "ids" { ... }
```

---

## 5. MODULE COMPOSITION PATTERNS

### 5.1 Root Module Orchestration
**Root module coordinates sub-modules.**

```hcl
# ✓ GOOD: Root orchestrates
module "vpc" {
  source = "./modules/vpc"
  name   = var.app_name
}

module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id  # Pass output as input
}

module "compute" {
  source           = "./modules/compute"
  security_group   = module.security.app_sg
  vpc_id           = module.vpc.vpc_id
  depends_on       = [module.security]  # Explicit dependency
}

# ✗ BAD: Root creates resources directly
resource "aws_vpc" "main" { ... }
resource "aws_security_group" "main" { ... }
resource "aws_instance" "main" { ... }
```

### 5.2 Module Dependencies
**Express dependencies clearly.**

```hcl
# ✓ GOOD: Implicit dependencies (preferred)
module "security" {
  source = "./modules/security"
  vpc_id = module.vpc.vpc_id  # Implicit dependency
}

# ✓ GOOD: Explicit when needed
module "compute" {
  source = "./modules/compute"
  depends_on = [module.security]  # Side effects not captured by references
}

# ✗ BAD: Hard-coded values
module "security" {
  source = "./modules/security"
  vpc_id = "vpc-12345"  # Hard-coded, not reusable
}

# ✗ BAD: Missing dependencies
module "compute" {
  source = "./modules/compute"
  # Missing vpc_id - implicit dependency missing
}
```

---

## 6. VERSION PINNING BEST PRACTICES

### 6.1 Provider Versioning
**Pin provider versions appropriately.**

```hcl
# ✓ GOOD: Pessimistic constraint
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"  # Allow 5.x.y
    }
  }
}

# ✓ GOOD: Terraform version
terraform {
  required_version = "~> 1.5"  # >= 1.5, < 1.6
}

# ✗ BAD: Too permissive
version = ">= 5.0"  # Allows major version jumps

# ✗ BAD: Too restrictive
version = "= 5.23.0"  # No security patches
```

### 6.2 Module Versioning (Public Registry)
**Pin module versions in root module.**

```hcl
# ✓ GOOD: Pinned version
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
}

# ✗ BAD: No version pinning
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  # No version - unsafe
}
```

### 6.3 Lock File
**Commit .terraform.lock.hcl.**

```bash
# ✓ GOOD: Commit lock file
git add .terraform.lock.hcl
git commit -m "Update provider lock file"

# ✗ BAD: Ignore lock file
# .terraform.lock.hcl not committed
```

---

## 7. TAGGING STRATEGY

### 7.1 Consistent Tagging
**Apply consistent tags across all resources.**

```hcl
# ✓ GOOD: Root module defines common tags
locals {
  common_tags = {
    Application = var.app_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Owner       = var.team_owner
    CostCenter  = var.cost_center
    CreatedDate = timestamp()
  }
}

# Pass to all modules
module "vpc" {
  source = "./modules/vpc"
  tags   = local.common_tags
}

module "compute" {
  source = "./modules/compute"
  tags   = local.common_tags
}

# ✗ BAD: Inconsistent tagging
resource "aws_instance" "web" {
  tags = { Name = "web" }  # Missing standard tags
}

resource "aws_instance" "app" {
  tags = {
    Name        = "app"
    Environment = "prod"
    Owner       = "devops"  # Different structure
  }
}
```

### 7.2 Merge Tags
**Merge common tags with module-specific tags.**

```hcl
# ✓ GOOD: Merge pattern
resource "aws_vpc" "main" {
  tags = merge(
    var.common_tags,
    {
      Name   = var.vpc_name
      Module = "VPC"
    }
  )
}

# ✗ BAD: Replace common tags
resource "aws_vpc" "main" {
  tags = {
    Name = var.vpc_name
    Module = "VPC"
    # Lost all common tags
  }
}
```

---

## 8. DOCUMENTATION BEST PRACTICES

### 8.1 Module README
**Each module needs clear README.md.**

```markdown
# VPC Module

## Description
Creates a VPC with public and private subnets across 3 AZs.

## Usage
\`\`\`hcl
module "vpc" {
  source = "./modules/vpc"
  
  vpc_name = "prod-vpc"
  cidr_block = "10.0.0.0/16"
  enable_nat = true
  tags = local.common_tags
}
\`\`\`

## Inputs
| Name | Type | Default | Description |
|------|------|---------|-------------|
| vpc_name | string | - | Name of VPC |
| cidr_block | string | 10.0.0.0/16 | CIDR block |
| enable_nat | bool | true | Enable NAT gateway |
| tags | map(string) | {} | Tags to apply |

## Outputs
| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| subnet_ids | Subnet IDs |
| nat_gateway_id | NAT gateway ID |

## Notes
- Creates 3 AZs automatically
- Requires VPC CIDR to be /16
```

### 8.2 Variable Documentation
**Document all variables clearly.**

```hcl
variable "enable_monitoring" {
  type        = bool
  description = "Enable CloudWatch monitoring for all resources. Required for production environments."
  default     = false
}

# ✗ BAD: No documentation
variable "enable_monitoring" {
  type    = bool
  default = false
}
```

---

## 9. TESTING BEST PRACTICES

### 9.1 Module Testing
**Test modules independently.**

```bash
# Create test configuration
mkdir -p modules/vpc/test

# modules/vpc/test/main.tf
module "vpc" {
  source = ".."
  
  vpc_name   = "test-vpc"
  cidr_block = "10.0.0.0/16"
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

# Run tests
cd modules/vpc/test
terraform init
terraform plan
terraform apply
terraform destroy
```

### 9.2 Composition Testing
**Test module interactions.**

```bash
# Test root module
terraform init
terraform plan
terraform apply
terraform destroy
```

---

## 10. SECURITY BEST PRACTICES

### 10.1 Secrets Management
**Never store secrets in modules.**

```hcl
# ✗ BAD: Secrets in state
variable "db_password" {
  type    = string
  default = "MyPassword123"  # Exposed in state!
}

# ✓ GOOD: Use Secrets Manager
resource "aws_secretsmanager_secret" "db" {
  name = "db-password"
}

# Reference at runtime
data "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
}
```

### 10.2 Sensitive Outputs
**Mark sensitive outputs.**

```hcl
# ✓ GOOD: Mark sensitive
output "db_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true  # Won't display in logs
}

# ✗ BAD: Expose secrets
output "db_password" {
  value = aws_db_instance.main.master_password
}
```

---

## 11. COMMON MISTAKES TO AVOID

| Mistake | Problem | Solution |
|---------|---------|----------|
| No variable validation | Invalid inputs fail late | Add validation blocks |
| Hard-coded values | Not reusable | Use variables and locals |
| No documentation | Unclear module usage | Add README and comments |
| No defaults | Verbose module calls | Provide sensible defaults |
| Modules too large | Hard to test/understand | Split into smaller modules |
| No tagging strategy | Can't track costs | Define common_tags locally |
| Unpinned versions | Breaking changes | Use ~> MAJOR.MINOR |
| No lock file | Version skew | Commit .terraform.lock.hcl |
| Secrets in state | Security risk | Use Secrets Manager |
| Unclear outputs | Over-exported info | Hide implementation |

---

## 12. QUICK REFERENCE CHECKLIST

### Before Creating a Module
- [ ] Define clear purpose (single responsibility)
- [ ] Document expected inputs
- [ ] Document expected outputs
- [ ] Plan reusability

### While Creating a Module
- [ ] Use variables for all configuration
- [ ] Provide sensible defaults
- [ ] Add validation rules
- [ ] Implement consistent tagging
- [ ] Create README.md
- [ ] Export essential outputs only
- [ ] Test independently

### In Root Module
- [ ] Import all child modules
- [ ] Pass outputs as inputs
- [ ] Use locals for common config
- [ ] Define common tags
- [ ] Aggregate and re-export outputs
- [ ] Version pin providers and modules

### For Distribution
- [ ] Document module purpose
- [ ] Version with git tags
- [ ] Maintain CHANGELOG.md
- [ ] Test with multiple provider versions
- [ ] Consider publishing to Terraform Registry

---

## 13. RESOURCES

- **Terraform Documentation**: https://www.terraform.io/language/modules
- **Registry**: https://registry.terraform.io/
- **Best Practices**: https://www.terraform.io/cloud-docs/recommended-practices
- **Module Development**: https://www.terraform.io/language/modules/develop

---

## Key Takeaways

1. **Single Responsibility**: Each module does one thing well
2. **Clear Contracts**: Explicit inputs/outputs with documentation
3. **Composition**: Build complex infrastructure from simple modules
4. **Versioning**: Pin major versions with pessimistic constraints
5. **Documentation**: README for each module, examples in root
6. **Tagging**: Consistent tagging across all resources
7. **Testing**: Test modules independently and as composition
8. **Security**: Never store secrets, use appropriate services
9. **Reusability**: Design for multiple uses and teams
10. **Simplicity**: Prefer simple, understandable code

---

Generated: Comprehensive Module Best Practices Guide covering all aspects of module development, composition, and management.
