# Terraform Conditionals — Interview Notes (concise)

## One-line definition
- Conditionals use the ternary operator (`condition ? true_value : false_value`) to choose values or enable/disable resources.

## Patterns
- Simple: `var.x ? "yes" : "no"`
- Nested: `var.a ? (var.b ? "x" : "y") : "z"`
- With `count`: `count = var.enable ? 1 : 0` (create resource only if true)
- Logical operators: `&&` (and), `||` (or), `!` (not)

## Short Q&A
- Q: How to conditionally create a resource?  
  A: Use `count = var.condition ? 1 : 0` or `for_each` with conditionals.
- Q: Can you use if/else statements?  
  A: No — Terraform uses ternary (`? :`), not if/else keywords.
- Q: How to combine conditions?  
  A: Use `&&` (and), `||` (or), `!` (not): `var.a && var.b ? "both" : "one or none"`

## Interview tip
- Explain that conditionals are expressions (not statements); they must always return a value. Use with `count` or `for_each` to conditionally create resources.
