# Terraform For Loops — Interview Notes (concise)

## One-line definition
- `for` expressions iterate over lists or maps to produce new collections.

## Syntax patterns
- On list: `[for item in var.list : item.property]`
- With index: `[for i, item in var.list : "${i}: ${item}"]`
- On map: `[for key, value in var.map : "${key}=${value}"]`
- With filter: `[for item in var.list : item if item.enabled]`

## Short Q&A
- Q: How to uppercase all strings in a list?  
  A: `[for s in var.names : upper(s)]`
- Q: How to get key-value pairs from a map?  
  A: `[for k, v in var.map : "${k}=${v}"]`
- Q: Can you filter in a for expression?  
  A: Yes — `[for item in var.list : item if condition]`

## Interview tip
- `for` expressions are different from loops in imperative languages — they transform collections. Combine with `count` or `for_each` to create multiple resources.
