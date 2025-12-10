# Multi-Region & Multi-Provider — Interview Notes (concise)

## One-line definition
- Use provider aliases to manage resources across regions or accounts from the same configuration.

## Key points
- Declare multiple provider blocks with `alias` and reference them in resources or modules.
- Pass providers into modules with `providers = { aws = aws.alias }` for explicit control.

## Short Q&A
- Q: How to create resources in two regions?  
  A: Define provider blocks with `alias` and set `provider = aws.alias` on resources.

- Q: How to share provider config to modules?  
  A: Use the `providers` argument in the module block to map providers into the module.

- Q: Best practices?  
  A: Keep provider configuration explicit, avoid ambiguous provider resolution, and consider separate state/backends for complex multi-account setups.

## Demo commands
```powershell
terraform init
terraform plan
```

## Interview tip
- Mention cross-account assumptions (credentials) and state management choices (single backend vs separate backends per region/account).
