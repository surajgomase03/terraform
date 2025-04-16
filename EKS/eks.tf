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
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_group_defaults = {
    
    instance_types = ["m6i.large", "m5.large", "m5n.large", "m5zn.large"]
    attach_cluster_primary_security_group = true
  }

  eks_managed_node_groups = {
    node_grp_first = {
      # Starting on 1.30, AL2023 is the default AMI type for EKS managed node groups
      instance_types = ["m5.xlarge"]
      min_size = 2
      max_size = 2
      desired_size = 2
      capacity_type = "SPOT"
    }
  }
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}