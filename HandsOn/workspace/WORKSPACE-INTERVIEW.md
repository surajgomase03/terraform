# Terraform Workspaces — Commands & Interview Notes

## Quick commands (PowerShell)

- Change to workspace folder
```powershell
cd 'd:\Study\Installtion\KaliShare\TERRAFORM\HandsOn\workspace'
```

- List workspaces
```powershell
terraform workspace list
```

- Show current workspace
```powershell
terraform workspace show
```

- Create a new workspace
```powershell
terraform workspace new dev
```

- Select an existing workspace
```powershell
terraform workspace select prod
```

- Create-or-select (common pattern)
```powershell
terraform workspace select dev || terraform workspace new dev
```

- Delete a workspace (only when empty or not holding state you need)
```powershell
terraform workspace delete test
```

## Short explanation (one-liners)

- A Terraform workspace provides separate state for the same configuration.
- Default workspace is named `default`.
- Use workspaces to manage multiple environments from the same code base (common: dev/stage/prod), but avoid mixing accounts/regions in the same backend without care.

## Examples (how to use in code)

- Reference workspace name inside config:
```hcl
resource "aws_s3_bucket" "state_bucket" {
  bucket = "myapp-${terraform.workspace}-bucket"
}
```

- Example workflow (create dev environment):
```powershell
terraform init
terraform workspace new dev
terraform plan -out=dev.plan
terraform apply "dev.plan"
```

## Interview-style Q&A (concise answers)

- Q: What is a Terraform workspace?
  - A: A named instance of state for the same configuration; each workspace keeps its own terraform.tfstate.

- Q: When should you use workspaces?
  - A: When you want multiple isolated states from the same configuration (e.g., dev vs prod) and differences between environments are small.

- Q: When should you NOT use workspaces?
  - A: Avoid for totally different infrastructures, for resources needing different providers/regions/accounts, or when separation is better achieved by separate repos/backends.

- Q: How does `terraform.workspace` help?
  - A: It exposes the active workspace name to the configuration so you can parameterize names/paths (e.g., bucket names, tags).

- Q: Are workspace names global or local?
  - A: Names are local to the configured backend. For remote backends each workspace corresponds to a separate state in that backend.

- Q: How do workspaces behave with remote backends (S3/remote)?
  - A: Remote backends store separate state entries per workspace; you must `init`/`select` correctly to operate on the intended state.

- Q: What are common pitfalls?
  - A: Relying on workspaces to separate accounts/regions; accidentally operating in the wrong workspace; using indexes/implicit naming that cause collisions; renaming workspace keys causes state confusion.

- Q: How to avoid mistakes in CI/CD?
  - A: Make CI select or create the correct workspace explicitly, fail if selection fails, and use an isolated backend per environment or dedicated backend config.

## Practical tips (short)

- Always run `terraform workspace show` in scripts to confirm the active workspace.
- Use workspace names like `dev`, `staging`, `prod` — keep them short, lower-case, and consistent.
- For complex infra differences prefer separate directories/repos or modules + different var-files instead of stuffing everything behind workspaces.
- When switching workspaces, re-run `terraform plan` (state changed) before `apply`.

## Commands checklist before apply (interview-style answer: safe practice)

1. `terraform fmt -recursive` — formatting
2. `terraform init` — initialize backend and providers
3. `terraform workspace select <env> || terraform workspace new <env>` — pick environment
4. `terraform validate` — quick lint
5. `terraform plan -out=plan.tfplan` — capture the plan
6. `terraform show plan.tfplan` — review plan
7. `terraform apply "plan.tfplan"` — apply

## One-line summary for interviews

- "Terraform workspaces create separate state instances for the same config; use them for light-weight environment separation but prefer distinct backends/repos for heavy or cross-account differences."

---
Generated: `HandsOn/workspace/WORKSPACE-INTERVIEW.md` (concise commands + interview Q&A)
