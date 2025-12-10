# Terraform `data` Sources — Interview Notes (short & focused)

Purpose: quick points and short Q&A to explain `data` sources in interviews.

## Core idea — one line
- `data` sources read provider-managed information (existing infra) and return values to use in your config; they do not create resources.

## Key points to memorize
- Read-only lookups: `data` reads values but Terraform does not manage the returned resource lifecycle.
- Determinism: prefer deterministic filters (tags/IDs). `most_recent = true` is convenient but can cause unexpected changes.
- Cost/latency: data lookups call provider APIs during plan/apply; expect API latency and rate limits.
- Secrets: use `aws_ssm_parameter` or Vault data sources; mark outputs/variables sensitive.

## Short code patterns
- AMI (quick demo):
```hcl
data "aws_ami" "latest" { most_recent = true owners = ["amazon"] }
output "ami" { value = data.aws_ami.latest.id }
```
- VPC/subnets:
```hcl
data "aws_vpc" "selected" { filter { name = "tag:Name" values = ["myvpc"] } }
data "aws_subnet_ids" "subs" { vpc_id = data.aws_vpc.selected.id }
```
- SSM secret (sensitive):
```hcl
data "aws_ssm_parameter" "pw" { name = "/app/db" with_decryption = true }
output "secret" { value = data.aws_ssm_parameter.pw.value sensitive = true }
```

## Interview Q&A (short answers)
- Q: What is a `data` source?  
  A: A read-only provider lookup for existing resources or values.

- Q: When to use `data` vs `resource`?  
  A: Use `data` when the resource is managed externally or already exists; use `resource` when Terraform should create/manage it.

- Q: Are `data` values stored in state?  
  A: No—`data` is evaluated during plan/apply. The resources that reference data may be stored in state, but `data` itself is not created as managed state objects.

- Q: Risk of `most_recent = true` on `aws_ami`?  
  A: The AMI can change over time, causing Terraform to plan replacements. For production, use pinned AMI IDs or stable filters.

- Q: How to keep secrets out of logs and state?  
  A: Use `sensitive = true` for outputs; avoid storing secrets in plain variables or in resources' attributes if possible; prefer dedicated secret stores.

- Q: Can data sources fail a plan?  
  A: Yes — if the provider API is unreachable or the lookup returns no results, plan/apply will fail.

## Quick demo steps (what to run in interview)
1. `terraform init`  
2. `terraform plan` (show it reads data)  
3. `terraform apply` (if you want to show outputs)  
4. `terraform output` (for non-sensitive outputs)

## One-line closing summary
- "Use `data` sources to read existing infra and secrets in a safe, read-only way — prefer deterministic lookups and treat outputs as sensitive when needed."

---
Generated: `HandsOn/Data/DATA-INTERVIEW.md` (short, interview-focused)
