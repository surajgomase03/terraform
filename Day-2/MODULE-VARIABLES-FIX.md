# Module Variables - Quick Reference

## Key Points

### 1. Module Variable Declaration
- Variables are declared in `variables.tf` within the module directory
- Must specify `type` (string, number, list, map, etc.)
- Optional: add `default` value or `description`

```hcl
variable "vpc" {
  type = string
}
```

### 2. Module Variable Usage
- Reference variables in module code using `var.<variable_name>`

```hcl
subnet_id = var.public
vpc_id    = var.vpc
```

### 3. Module Call - Passing Variables
- When calling a module, pass required variables as arguments

```hcl
module "EC2" {
  source = "./modules/EC2/"
  public = module.vpc.public
}

module "igw" {
  source = "./modules/IGW/"
  vpc = module.vpc.vpc
}
```

### 4. Module Outputs
- Export values from modules using `output` blocks

```hcl
output "vpc" {
  value = aws_vpc.demovpc.id
}

output "public" {
  value = aws_subnet.demopublicsubnet.id
}
```

### 5. Reference Module Outputs
- Access module outputs: `module.<module_name>.<output_name>`

```hcl
public = module.vpc.public    # Get "public" output from "vpc" module
vpc    = module.vpc.vpc       # Get "vpc" output from "vpc" module
```

## Common Errors & Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| Missing required argument | Variable not passed to module | Add variable to module call |
| Unsupported argument | Wrong variable name | Match variable name in `variables.tf` |
| Output not found | Module output doesn't exist | Check module's `output.tf` file |

## Quick Checklist

- [ ] Module has `variables.tf` with required variables
- [ ] Module has `output.tf` with exported values
- [ ] Root module passes all required variables
- [ ] Variable names match between call and declaration
- [ ] Output names match when referencing
