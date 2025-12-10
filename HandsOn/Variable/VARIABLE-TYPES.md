# Terraform Variable Types — Interview Notes (concise)

Purpose: short, interview-focused explanations and Q&A for each Terraform variable type.

## Types covered
- string, number, bool, list(string), map(string), object({ ... })

## Quick summaries
- string: single text value. Example: `variable "app_name" { type = string }`.
- number: numeric values used for counts, sizes. Example: `instance_count`.
- bool: true/false flags. Example: feature toggles.
- list(string): ordered collection. Access by index. Use for ordered AZs, CIDRs.
- map(string): key/value pairs. Use for tags or keyed config.
- object: structured group of typed attributes. Use for complex inputs (db config).

## Short Q&A (practice answers)
- Q: How do you declare a list of strings?  
  A: `variable "azs" { type = list(string) }`

- Q: How to access the first element of a list variable?  
  A: `var.azs[0]` or `element(var.azs, 0)`.

- Q: How to reference a map value keyed by `Env`?  
  A: `var.default_tags["Env"]`.

- Q: When to use `object` type?  
  A: When a variable logically groups multiple typed fields (e.g., db config), giving compile-time checks and clearer contracts.

- Q: How to make a variable required?  
  A: Omit `default` — Terraform will require a value via-cli or tfvars.

- Q: How to pass variables in CI or scripts?  
  A: Use `-var-file` with a `terraform.tfvars` or environment variables (TF_VAR_<name>).

## Common pitfalls
- Using untyped variables (no type) can accept wrong shapes — prefer typed variables for production.
- Using lists where keyed access is required — prefer `map` or `for_each` with maps for stable identity.
- Sensitive values: do not store secrets in VCS; use secret manager or mark outputs/variables sensitive.

## Quick demo commands
```powershell
# format and validate
terraform fmt
terraform validate

# plan with a var-file
terraform plan -var-file="terraform.tfvars"

# override single var
terraform plan -var="instance_count=3"
```

## Interview tip
- Show you understand trade-offs: typed variables enforce contracts; `object` gives structure but reduces flexibility. For secrets, use external secret stores and avoid committing `terraform.tfvars` with secrets.

---
Generated: `HandsOn/Variable/VARIABLE-TYPES-INTERVIEW.md`