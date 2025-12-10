# multi-provider-demo.tf
# Demonstrates provider aliases for multi-region or multi-account usage.

provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_west"
  region = "us-west-2"
}

# Resource in us-east using provider alias
resource "aws_vpc" "east_vpc" {
  provider = aws.us_east
  cidr_block = "10.0.0.0/16"
  tags = { Name = "east-vpc" }
}

# Resource in us-west using provider alias
resource "aws_vpc" "west_vpc" {
  provider = aws.us_west
  cidr_block = "10.1.0.0/16"
  tags = { Name = "west-vpc" }
}

# Passing providers into modules (example)
# module "multi" {
#   source = "./modules/foo"
#   providers = { aws = aws.us_east }
# }
