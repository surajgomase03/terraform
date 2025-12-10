# Provisioners — Interview Notes (concise)

## One-line definition
- Provisioners run actions on or from resources during create/destroy (e.g., `remote-exec`, `local-exec`).

## Key points
- Prefer cloud-init, user-data, or configuration management tools over provisioners for idempotency and reliability.
- `remote-exec` requires connectivity and credentials; `local-exec` runs on the machine executing Terraform.

## Short Q&A
- Q: When to use provisioners?  
  A: As a last resort for actions Terraform cannot perform (legacy systems, bootstrap steps). Prefer other methods.

- Q: What are the risks?  
  A: Provisioners can fail unpredictably, make plans non-idempotent, and rely on runtime connectivity.

## Commands / demo
```powershell
terraform init
terraform plan
terraform apply
```

## Interview tip
- Explain alternatives (user-data, Ansible, Packer) and that provisioners are an escape-hatch, not the primary mechanism.
