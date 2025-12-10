# Terraform Variables — Interview Notes (concise)

## One-line definition
- Variables parameterize Terraform configuration; they support types (string, number, bool, list, map, object).

## Key points
- Provide defaults or require values; use `-var-file` or env vars for CI.
- Sensitive variables: mark outputs sensitive; avoid storing secrets in VCS.

## Short Q&A
- Q: How to pass variables in CI?  
  A: Use `-var-file`, environment variables, or secret management (Vault).

- Q: What are variable types?  
  A: string, number, bool, list, map, set, object, tuple.

- Q: How to make a variable required?  
  A: Omit `default` so Terraform requires the value.

## Demo commands
```powershell
terraform plan -var-file="terraform.tfvars"
terraform apply -var='instance_count=3'
```

## Interview tip
- Discuss trade-offs of tfvars in repo vs external secret management and demonstrate variable typing for safer configurations.
