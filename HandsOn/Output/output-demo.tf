# output-demo.tf
# Demonstrates outputs and sensitive outputs

resource "random_pet" "name" {
  length = 2
}

output "pet_name" {
  value = random_pet.name.id
}

output "masked_secret" {
  value     = "super-secret-value"
  sensitive = true
}
