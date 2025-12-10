# 📘 Terraform Notes -- Module Outputs & Cross-Module References

## 1. Why Outputs Are Needed in Terraform Modules

-   Each Terraform module is **isolated**.
-   A module cannot directly access resources from another module.
-   To share values (like subnet ID, VPC ID, IGW ID) between modules,
    Terraform uses:

```{=html}
<!-- -->
```
    Module A → output → Root module → variable → Module B

## 2. How Value Flow Works

    [VPC Module] --output--> [Root Module] --variable--> [EC2 Module]

## 3. Example: Create Output in VPC Module

### modules/vpc/outputs.tf

``` hcl
output "public_subnet_id" {
  value = aws_subnet.public.id
}
```

## 4. Root Module Passing the Value to EC2 Module

### main.tf

``` hcl
module "ec2" {
  source    = "./modules/ec2"
  subnet_id = module.vpc.public_subnet_id
}
```

## 5. EC2 Module Declares Variable to Receive Value

### modules/ec2/variables.tf

``` hcl
variable "subnet_id" {}
```

### modules/ec2/main.tf

``` hcl
resource "aws_instance" "server" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
}
```

## 6. Common Errors

### Error: "value must be declared"

Cause: variable not declared.

### Error: "Unsupported attribute"

Cause: wrong output name.

### Error: output not defined

Fix by adding an output block in module.

## 7. Golden Rule

    OUTPUT → VARIABLE → USE

## 8. Summary

-   Use outputs to share values between modules.
-   Root module passes outputs to other modules.
-   Receiving module must declare variables.
