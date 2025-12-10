# Terraform Functions — Interview Notes (concise)

## One-line definition
- Terraform provides built-in functions for string, numeric, list, and map operations.

## Common categories
- String: `upper()`, `lower()`, `length()`, `join()`, `split()`, `regex()`
- Numeric: `min()`, `max()`, `abs()`, `ceil()`, `floor()`
- List/Map: `concat()`, `contains()`, `keys()`, `values()`, `merge()`, `lookup()`
- Type conversion: `tostring()`, `tonumber()`, `tolist()`, `tomap()`

## Short Q&A
- Q: How to join list items with a separator?  
  A: `join(",", var.items)`
- Q: How to check if a value is in a list?  
  A: `contains(var.list, "value")`
- Q: How to get keys from a map?  
  A: `keys(var.map)`

## Demo command
```powershell
terraform console
# then: upper("test"), join(",", ["a","b","c"]), contains(["dev","prod"], "dev")
```

## Interview tip
- Know common functions (join, split, concat, contains); you'll use them in interpolations, conditionals, and dynamic blocks. Terraform documentation lists all functions.
