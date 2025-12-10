# Drift Detection — Interview Notes (concise)

Purpose: short, practical answers and commands to explain drift detection in interviews.

## One-line definition
- Drift is any difference between real-world infrastructure and Terraform state/configuration.

## How to detect drift (commands)
- `terraform plan`  
  - Shows differences between current config + state and provider; changed resources appear in the plan.
- `terraform refresh`  
  - Updates the local state from the provider without making changes; follow with `terraform plan` to inspect differences.
- `terraform state list` / `terraform state show <address>`  
  - Inspect state and compare desired attributes.

## How to simulate drift (for demos)
- Create a resource with Terraform (e.g., S3 bucket or EC2).  
- Modify the resource outside Terraform (console or CLI), e.g., change a tag, toggle versioning, change security group rules.  
- Run `terraform plan` to see the drift.

## How to resolve drift
- If external change is intended: update Terraform configuration to match the external change, then `terraform apply` to record it in state.
- If Terraform should be the source of truth: run `terraform apply` to revert external change (Terraform will update provider).  
- To stop managing a resource: `terraform state rm <address>` (resource remains in cloud but not managed by Terraform).
- To re-import resource into Terraform state after manual changes: `terraform import <address> <id>`, then `terraform plan` and update config as needed.

## Common interview Q&A (short answers)
- Q: What is drift?  
  A: Divergence between real infrastructure and Terraform-managed state/config.

- Q: How do you detect drift?  
  A: Run `terraform plan` or `terraform refresh` and inspect changes; CI can run periodic plans for detection.

- Q: How do you fix drift safely?  
  A: Decide which source is correct; either update config to match real infra (then apply) or apply Terraform to enforce config (running `terraform apply`).

- Q: When would you remove a resource from state?  
  A: When you no longer want Terraform to manage it but want the resource to continue existing (use `terraform state rm`).

- Q: How can CI detect drift?  
  A: Schedule `terraform plan` runs and fail if plan shows changes; optionally notify owners.

- Q: Any pitfalls?  
  A: Automated `refresh`/`plan` may cause transient differences due to provider timing; ensure plans are reviewed. Also, applying drift fixes without review can cause unintended changes.

## Quick practical demo steps (PowerShell)
1. `terraform init`  
2. `terraform apply -auto-approve`  
3. Make an external change (console or CLI) to a resource created above  
4. `terraform plan` — see drift reported  
5. `terraform refresh`  
6. `terraform plan` — inspect updated plan

## One-line interview summary
- "Drift is divergence between actual infra and Terraform state; detect with `terraform plan`/`refresh` and resolve by deciding the desired source of truth and either updating config or applying Terraform to reconcile."
