# Terraform Modules — Interview Notes (concise)

## One-line definition
- Modules are reusable packages of Terraform configuration that encapsulate resources, inputs, and outputs.

## Key points
- Use modules to DRY code, encapsulate best-practices, and share across projects.
- Modules can be local (file path), in VCS, or published in the Terraform Registry.
- Document inputs (`variables.tf`) and outputs (`outputs.tf`) clearly.

## Short Q&A
- Q: How do you version modules?  
  A: Use registry modules with versions or reference git tags/commit SHAs for stability.

- Q: How to pass providers to modules?  
  A: Use `providers = { aws = aws.alias }` in the module block or configure provider aliases inside modules cautiously.

- Q: How to test modules?  
  A: Use small example root modules, Terratest, or run `terraform plan`/`apply` in sandbox accounts.

## Commands (demo)
```powershell
# from root containing module-demo.tf
terraform init
terraform plan
```

## Interview tip
- Explain module boundaries, input/output contracts, and how to version and publish modules for reuse. Emphasize testing and documentation.
