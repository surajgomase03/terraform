# Terraform Interpolation — Interview Notes (concise)

## One-line definition
- Interpolation embeds expressions inside strings using `${...}` syntax.

## Syntax
- Simple: `"Hello ${var.name}"`
- Functions: `"${upper(var.name)}"`
- Conditionals: `"${var.prod ? "Production" : "Development"}"`
- Arithmetic: `"Port ${var.port + 100}"`

## Short Q&A
- Q: How to embed a variable in a string?  
  A: `"Value is ${var.x}"`
- Q: Can you use function calls in interpolation?  
  A: Yes — `"${upper(var.name)}"`
- Q: What happens if you don't use interpolation syntax?  
  A: `"var.name"` is literal text; `"${var.name}"` evaluates the variable.

## Interview tip
- Interpolation is syntactic sugar for string concatenation; understand when to use it vs keeping values separate (e.g., for resource dependencies, keep IDs separate).
