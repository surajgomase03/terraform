# functions-demo.tf
# Demonstrates Terraform built-in functions: string, numeric, list, map, type conversion.

# String functions
output "upper_example" {
  value = upper("hello")
}

output "lower_example" {
  value = lower("WORLD")
}

output "strlen_example" {
  value = length("terraform")
}

output "join_example" {
  value = join(",", ["a", "b", "c"])
}

output "split_example" {
  value = split(",", "x,y,z")
}

output "regex_example" {
  value = regex("[0-9]+", "abc123def")
}

# Numeric functions
output "min_example" {
  value = min(5, 2, 8)
}

output "max_example" {
  value = max(5, 2, 8)
}

output "abs_example" {
  value = abs(-42)
}

# List/Map functions
output "concat_example" {
  value = concat([1, 2], [3, 4])
}

output "contains_example" {
  value = contains(["dev", "staging", "prod"], "dev")
}

output "keys_example" {
  value = keys({"a" = 1, "b" = 2})
}

output "values_example" {
  value = values({"x" = 10, "y" = 20})
}

# Type conversion
output "tostring_example" {
  value = tostring(123)
}

output "tonumber_example" {
  value = tonumber("456")
}

output "tolist_example" {
  value = tolist(["a", "b"])
}
