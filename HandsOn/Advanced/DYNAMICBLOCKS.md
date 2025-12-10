# Terraform Dynamic Blocks — Interview Notes (concise)

## One-line definition
- Dynamic blocks repeat nested arguments (e.g., ingress rules) using `for_each` or `for` expressions.

## Syntax
```hcl
dynamic "block_name" {
  for_each = var.items
  content {
    nested_arg = block_name.value.property
  }
}
```

## When to use
- When a resource or nested block needs repeating (ingress rules, tags, etc.).
- Avoid over-using; prefer separate resources when possible (e.g., `aws_security_group_rule` instead of dynamic ingress).

## Short Q&A
- Q: What's the difference between dynamic block and for_each resource?  
  A: Dynamic blocks repeat nested arguments within one resource; `for_each` creates separate resources.
- Q: How to reference the loop variable in dynamic?  
  A: `block_name.value` or `block_name.key` (if using map).

## Interview tip
- Dynamic blocks are powerful but can make configs hard to read. Prefer separate resources or modules when feasible; use dynamic blocks for tightly coupled nested structures.
