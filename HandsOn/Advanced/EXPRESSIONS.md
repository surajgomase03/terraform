# Terraform Expressions — Interview Notes (concise)

## One-line definition
- Expressions are values, references, operations, and function calls that produce results.

## Types of expressions
- Literals: `"string"`, `123`, `true`
- References: `var.name`, `aws_instance.web.id`
- Conditionals: `var.x ? true_val : false_val`
- Functions: `upper()`, `length()`, `join()`, etc.
- Arithmetic/logic: `+`, `-`, `*`, `/`, `&&`, `||`, `!`

## Short Q&A
- Q: What is an expression?  
  A: A Terraform language construct that produces a value (variables, literals, function calls, operators).
- Q: How to use arithmetic in Terraform?  
  A: `var.count + 1`, `var.port * 2`, etc.

## Quick commands
```powershell
terraform console  # interactive REPL to test expressions
# Then: upper("hello"), 5 + 3, var.enable_feature ? "yes" : "no"
```

## Interview tip
- Expressions are the building blocks of Terraform language; understanding them helps with conditionals, dynamic blocks, and complex configurations.
