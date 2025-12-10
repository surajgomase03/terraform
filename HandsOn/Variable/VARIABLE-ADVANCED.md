# Advanced Variables — Validation, Precedence & .tfvars (Interview Notes)

This file covers three related topics: variable validation, variable precedence, and variable files (`.tfvars`) with concise answers and commands for interviews.

---

## Variable Validation (short)
- Purpose: enforce constraints on variable values early (plan time) using `validation` blocks.
- Syntax: inside a `variable` block add `validation { condition = <expr> error_message = "..." }`.
- When to use: ensure numeric ranges, allowed strings, non-empty lists, or complex conditions.

Example (one-line):
```hcl
variable "port" { type = number validation { condition = var.port >= 1024 && var.port <= 65535 error_message = "Port must be 1024-65535" } }
```

Interview Q&A — validation
- Q: When is variable validation evaluated?  
  A: During `plan`/`apply` evaluation of variables.
- Q: How to show a custom error?  
  A: Set `error_message` in the `validation` block.
- Q: Can you use functions in `condition`?  
  A: Yes — you can use built-in functions (contains, length, regex, etc.) in the condition.

---

## Variable Precedence (short)
- Terraform variable precedence (highest → lowest):
  1) CLI `-var` or `-var-file` with `-var` present for specific variables
  2) Environment variables: `TF_VAR_name`
  3) `terraform.tfvars` and `terraform.tfvars.json`
  4) `*.auto.tfvars` and `*.auto.tfvars.json`
  5) Variable defaults in configuration
  6) Provider/module defaults (if any)

- Practical implications: for reproducible CI runs, prefer explicit `-var-file` or use environment secrets (TF_VAR_). Avoid relying on implicit `*.auto.tfvars` files unless intended.

Interview Q&A — precedence
- Q: Which wins: TF_VAR_x or terraform.tfvars?  
  A: `TF_VAR_x` (environment variable) has higher precedence than `terraform.tfvars`.
- Q: How to provide env-specific values in CI?  
  A: Use `-var-file` per environment or set `TF_VAR_` environment variables in CI securely.

---

## Variable Files (`.tfvars`) (short)
- Common files:
  - `terraform.tfvars` — automatically loaded by Terraform if present.
  - `terraform.tfvars.json` — JSON equivalent.
  - `*.auto.tfvars` — auto-loaded files (useful for environment defaults).
  - Custom var files: `terraform plan -var-file="dev.tfvars"` (explicit loading).
- Security: never commit secrets in `terraform.tfvars` to VCS. Use secret managers or CI secure variables.

Example `terraform.tfvars.example` usage:
- Add `terraform.tfvars.example` to repo with placeholder values.
- Copy to `terraform.tfvars` locally and edit values (do not commit actual `terraform.tfvars`).

Interview Q&A — tfvars
- Q: How to pass a single variable on CLI?  
  A: `terraform plan -var='instance_count=3'`
- Q: How to use a var-file with plan?  
  A: `terraform plan -var-file="prod.tfvars"`
- Q: Why keep `terraform.tfvars.example`?  
  A: To document needed variables and provide a template for engineers without committing secrets.

---

## Quick demo commands
```powershell
# Validate & test validation rules
terraform init
terraform plan -var='port=80'   # should show validation error for port if out of range

# Test precedence
# 1) using var-file
terraform plan -var-file="terraform.tfvars"
# 2) overriding with env var
$env:TF_VAR_app_name = 'env-app'
terraform plan
# 3) overriding with CLI
terraform plan -var='app_name=cli-app'

# Example: do not commit secrets; use terraform.tfvars.example as template
```

---

## One-line interview summary
- "Use variable validation to enforce input constraints, understand precedence so intended values win in CI/scripted runs (CLI > TF_VAR > tfvars > defaults), and keep a `terraform.tfvars.example` template while storing real secrets securely outside VCS."

Generated: `HandsOn/Variable/VARIABLE-ADVANCED-INTERVIEW.md`
