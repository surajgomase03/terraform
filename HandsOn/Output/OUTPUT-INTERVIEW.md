# Terraform Outputs — Interview Notes (concise)

## One-line definition
- Outputs expose values from modules or root config for consumption by humans, scripts, or other modules.

## Key points
- Use `sensitive = true` for secrets to avoid printing them in CLI output.
- Outputs can be used by other modules when using the `module.<name>.<output>` syntax.

## Short Q&A
- Q: How to make an output secret?  
  A: `output "pw" { value = aws_ssm_param.value sensitive = true }`

- Q: How to reference a module output?  
  A: `module.<module_name>.<output_name>`

## Commands
```powershell
terraform output
terraform output -json
```

## Interview tip
- Explain where outputs appear (CLI, automation) and state sensitivity considerations.
