# State Locking — Interview Notes (concise)

## One-line definition
- State locking prevents concurrent operations that could corrupt the Terraform state; supported by many remote backends.

## Key points
- S3 + DynamoDB is a common AWS pattern: S3 stores state, DynamoDB provides locks.
- Terraform Cloud and other remote backends provide automatic locking.

## Short Q&A
- Q: Why is locking important?  
  A: To avoid concurrent `apply`/`plan` that lead to state corruption or race conditions.

- Q: Which backends support locking?  
  A: S3+DynamoDB, Terraform Cloud, Azure RM, and others.

## Demo commands
```powershell
terraform init
# From two shells attempt concurrent terraform apply to observe locking
terraform apply
```

## Interview tip
- Explain how locking works briefly and mention DynamoDB table schema requirement (LockID key) for S3 backend.
