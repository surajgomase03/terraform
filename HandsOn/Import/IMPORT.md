# Terraform Import — Interview Notes (concise)

## One-line definition
- `terraform import` brings an existing resource into Terraform state without creating it.

## Key steps (short)
1. Add a resource block to your config that matches the real resource type.
2. Run `terraform import <address> <id>` to map the real resource into state.
3. Run `terraform plan` and update the config to match resource attributes (so apply does not recreate).

## Short Q&A
- Q: Does `terraform import` create config?  
  A: No — it only updates state. You must provide a matching resource block.

- Q: What if plan shows changes after import?  
  A: Update the resource block to reflect the real resource attributes, or use `terraform state` to inspect and reconcile.

- Q: Can you import multiple resources?  
  A: Yes — script `terraform import` commands or automate via loops.

## Quick commands
```powershell
# Example
terraform import aws_instance.web i-0123456789abcdef0
terraform plan
```

## Interview tip
- Emphasize careful validation after import — mismatch between config and resource causes replacements. Use `terraform state show` to inspect imported attributes.
