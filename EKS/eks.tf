module "eks" {
  source  = "terraform-aws-modules/eks/aws"    # Most Imp
  version = "~> 20.31"                         # optional   

  cluster_name    = local.name
  cluster_version = "1.31"

  # Optional
  cluster_endpoint_public_access = true

  # Optional: Adds the current caller identity as an administrator via cluster access entry
  enable_cluster_creator_admin_permissions = true

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets


  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}