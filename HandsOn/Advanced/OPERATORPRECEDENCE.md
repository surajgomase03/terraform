# Terraform Operator Precedence — Interview Notes (concise)

## One-line definition
- Operator precedence determines the order in which Terraform evaluates operations; use parentheses to override.

## Precedence order (highest → lowest)
1) `()` parentheses, `[]` indexing
2) `!` (not)
3) `*`, `/`, `%` (multiply, divide, modulo)
4) `+`, `-` (addition, subtraction)
5) `>`, `<`, `>=`, `<=` (comparison)
6) `==`, `!=` (equality)
7) `&&` (logical AND)
8) `||` (logical OR)
9) `?:` (ternary conditional — right associative)

## Short Q&A
- Q: What does `a + b * c` evaluate to?  
  A: `a + (b * c)` — multiply before add.
- Q: What does `a && b || c` evaluate to?  
  A: `(a && b) || c` — AND before OR.
- Q: How to change evaluation order?  
  A: Use parentheses: `(a + b) * c`

## Interview tip
- Remember key precedence: `!` before `&&`, `&&` before `||`; multiplication/division before addition/subtraction. Use parentheses for clarity even when not strictly needed.
