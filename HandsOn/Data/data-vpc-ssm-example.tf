# data-vpc-ssm-example.tf
# Demonstrates reading existing VPC/subnet IDs and SSM parameter values using data sources.
# Safe to run if provider configured; no resources are created by the data blocks themselves.

variable "vpc_name" {
  type    = string
  default = "myvpc"
}

# Look up existing VPC by Name tag
data "aws_vpc" "selected_vpc" {
  filter {
    name   = "tag:Name"
    values = [var.vpc_name]
  }
}

# Get subnet ids for that VPC
data "aws_subnet_ids" "vpc_subnets" {
  vpc_id = data.aws_vpc.selected_vpc.id
}

# Read a parameter from SSM Parameter Store (example: /myapp/db_password)
variable "ssm_param_name" {
  type    = string
  default = "/myapp/db_password"
}

data "aws_ssm_parameter" "db_password" {
  name = var.ssm_param_name
  with_decryption = true
}

output "vpc_id" {
  value = data.aws_vpc.selected_vpc.id
}

output "subnet_ids" {
  value = data.aws_subnet_ids.vpc_subnets.ids
}

output "db_password_from_ssm" {
  value     = data.aws_ssm_parameter.db_password.value
  sensitive = true
}

# Interview/demo notes:
# - Use data sources to reference existing infra or secrets without recreating them.
# - Always be cautious exposing `sensitive` outputs; mark them sensitive and avoid printing in shared logs.
