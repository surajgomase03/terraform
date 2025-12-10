module "vpc" {
  source = "./modules/vpc"
}
module "igw" {
  source = "./modules/IGW/"
  vpc = module.vpc.vpc
}
module "EC2" {
  source = "./modules/EC2/"
  public = module.vpc.public
}

