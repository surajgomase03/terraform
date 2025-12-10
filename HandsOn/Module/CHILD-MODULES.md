# Child Modules — Interview Notes

## Quick Definition
Child modules are reusable Terraform modules called by a root module (or other modules) that encapsulate related resources.

## Q&A Format

### Q: What is a child module?
**A:** 
A module called by parent module that:
- Has own `variables.tf` (inputs)
- Has own resources
- Has own `outputs.tf` (exports)
- Single responsibility (e.g., VPC, Security, Database)
- Reusable across projects

### Q: Child module structure?
**A:** 
```
modules/vpc/
├── main.tf         # Resources
├── variables.tf    # Input variables
├── outputs.tf      # Output values
└── README.md       # Documentation
```

### Q: How to create child module?
**A:** 
```hcl
# Step 1: Create directory
mkdir -p modules/vpc

# Step 2: Create variables.tf
variable "vpc_name" {
  type = string
}

# Step 3: Create main.tf
resource "aws_vpc" "main" {
  cidr_block = var.vpc_name
}

# Step 4: Create outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

# Step 5: Call from root
module "vpc" {
  source = "./modules/vpc"
  vpc_name = "prod-vpc"
}
```

### Q: Child module inputs (variables)?
**A:** 
- Required: No default value
- Optional: Has default value
- Validate: Add validation rules
- Describe: Always document

```hcl
variable "instance_count" {
  type        = number
  description = "Number of instances"
  default     = 1
  validation {
    condition     = var.instance_count > 0
    error_message = "Must be > 0"
  }
}
```

### Q: Child module outputs?
**A:** 
Export only essential values:
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}

# Don't export everything
# Hide implementation details
# Only expose public API
```

### Q: Can child modules call other modules?
**A:** 
Yes, nested modules:
```hcl
# modules/networking/main.tf
module "vpc" {
  source = "./vpc"
}

module "security" {
  source = "./security"
}
```

But keep nesting shallow (2-3 levels max).

### Q: Child module versioning?
**A:** 
For local modules: No version (uses current code)
For remote modules:
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"  # Pin version
}
```

### Q: Child module testing?
**A:** 
Create test configuration:
```
modules/vpc/
├── main.tf
├── variables.tf
├── outputs.tf
└── test/
    ├── main.tf  # Test this module in isolation
    └── terraform.tfvars
```

### Q: Child module reusability?
**A:** 
Design for multiple uses:
- Don't hard-code values
- Accept all configuration via variables
- Provide sensible defaults
- Use locals for derived values
- Clear documentation

### Q: Child module single responsibility?
**A:** 
Each module should do one thing:
- VPC module: only VPC infrastructure
- Security module: only security groups
- Compute module: only EC2/ASG
- Database module: only RDS/DynamoDB

Easier to test, maintain, and reuse.

---

## Module Design Checklist

- [ ] Clear purpose (documented)
- [ ] All inputs as variables
- [ ] Sensible defaults
- [ ] Clear outputs
- [ ] Validation on inputs
- [ ] Consistent tagging
- [ ] README with examples
- [ ] Tested in isolation
- [ ] No hard-coded values
- [ ] No provider blocks (inherit from parent)

---

## Key Takeaway
Child modules encapsulate related infrastructure, promoting reusability and maintainability. Design for single responsibility and clear input/output contracts.
