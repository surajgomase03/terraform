module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = local.name
  cidr = local.vpc_cidr

  azs             = ["us-west-1a", "us-west-1b", "us-west-1c"]
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true
  enable_vpn_gateway = true

  tags = {
    Terraform = "true"
    Environment = local.env
  }
}