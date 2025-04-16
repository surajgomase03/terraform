locals {
  name = "first_EKS_cluster"
  region = "us-east-1"
  env = "dev"
  vpc_cidr = "10.0.0.0/16"
  private_subnets =["10.0.2.0/24","10.0.3.0/24"]
  public_subnets = ["10.0.3.0/24","10.0.4.0/24"]
  intra_subnets = ["10.0.5.0/24","10.0.6.0/24"]

}