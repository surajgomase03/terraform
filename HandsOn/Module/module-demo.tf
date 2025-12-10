# module-demo.tf
# Example showing creating and calling a simple module (local module)

# Root module calling a local 'web' module
module "web" {
  source = "./modules/web"

  instance_count = 2
  instance_type  = "t2.micro"
}

# Note: create ./modules/web/main.tf with inputs `instance_count` and `instance_type`.
# Run: terraform init && terraform plan
