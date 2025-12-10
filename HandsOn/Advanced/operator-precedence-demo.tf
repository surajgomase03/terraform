# operator-precedence-demo.tf
# Demonstrates Terraform operator precedence and grouping with parentheses.

variable "a" {
  type    = number
  default = 10
}

variable "b" {
  type    = number
  default = 5
}

variable "c" {
  type    = number
  default = 2
}

# Arithmetic precedence: *, / before +, -
output "precedence_arithmetic" {
  value = var.a + var.b * var.c  # 10 + (5 * 2) = 20, not (10 + 5) * 2 = 30
}

# Logical precedence: ! before && before ||
output "precedence_logical" {
  value = true && false || true  # (true && false) || true = true
}

# Comparison and logical together
output "precedence_mixed" {
  value = var.a > var.b && var.b < var.c  # (10 > 5) && (5 < 2) = true && false = false
}

# Using parentheses to override precedence
output "with_parentheses_1" {
  value = (var.a + var.b) * var.c  # (10 + 5) * 2 = 30
}

output "with_parentheses_2" {
  value = var.a + (var.b * var.c)  # 10 + (5 * 2) = 20 (same as without parens)
}

# Operator precedence reference (highest to lowest):
# 1) () - parentheses, [] - indexing
# 2) ! (not)
# 3) * / % (multiply, divide, modulo)
# 4) + - (addition, subtraction)
# 5) > < >= <= (comparison)
# 6) == != (equality)
# 7) && (logical AND)
# 8) || (logical OR)
# 9) ?: (ternary conditional - right associative)
