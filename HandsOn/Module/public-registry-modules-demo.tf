# Public Registry Modules Demo
# Demonstrates using modules from Terraform Registry and other sources

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ============================================================================
# PUBLIC REGISTRY MODULES
# ============================================================================
# Modules available from: https://registry.terraform.io/
# Maintained by HashiCorp, AWS, and community

# ============================================================================
# EXAMPLE 1: VPC Module (terraform-aws-modules/vpc/aws)
# ============================================================================

module "vpc_public" {
  # Source: Registry path and version
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  # Input variables
  name            = "prod-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["us-east-1a", "us-east-1b", "us-east-1c"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway = true
  enable_vpn_gateway = false
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "prod-vpc"
    Environment = "prod"
  }
}

# ============================================================================
# EXAMPLE 2: Security Group Module (terraform-aws-modules/security-group/aws)
# ============================================================================

module "alb_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = module.vpc_public.vpc_id

  # Predefined rules for ALB
  ingress_rules       = ["http-80-tcp", "https-443-tcp"]
  ingress_cidr_blocks = ["0.0.0.0/0"]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "alb-sg"
  }
}

module "app_security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "app-sg"
  description = "Security group for application servers"
  vpc_id      = module.vpc_public.vpc_id

  # Custom rules for app servers
  ingress_with_source_security_group_id = [
    {
      from_port                = 8080
      to_port                  = 8080
      protocol                 = "tcp"
      source_security_group_id = module.alb_security_group.security_group_id
    }
  ]

  egress_rules       = ["all-all"]
  egress_cidr_blocks = ["0.0.0.0/0"]

  tags = {
    Name = "app-sg"
  }
}

# ============================================================================
# EXAMPLE 3: RDS Module (terraform-aws-modules/rds/aws)
# ============================================================================

module "rds_postgres" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 6.0"

  identifier = "prod-postgres"

  # Database configuration
  engine               = "postgres"
  engine_version       = "15.2"
  family               = "postgres15"
  major_engine_version = "15"
  instance_class       = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100  # Auto-scaling
  storage_encrypted     = true
  storage_type          = "gp3"

  # Credentials
  db_name  = "appdb"
  username = "dbadmin"
  # password = var.db_password  # Use variable for sensitive data

  # High availability
  multi_az               = true
  publicly_accessible    = false
  vpc_security_group_ids = [module.app_security_group.security_group_id]
  db_subnet_group_name   = module.vpc_public.database_subnet_group_name

  # Backup and maintenance
  backup_retention_period = 30
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"
  skip_final_snapshot     = false
  final_snapshot_identifier = "prod-postgres-final-snapshot"

  # Enhanced monitoring
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Environment = "prod"
  }
}

# ============================================================================
# EXAMPLE 4: ALB Module (terraform-aws-modules/alb/aws)
# ============================================================================

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 9.0"

  name            = "prod-alb"
  load_balancer_type = "application"
  vpc_id          = module.vpc_public.vpc_id
  subnets         = module.vpc_public.public_subnets
  security_groups = [module.alb_security_group.security_group_id]

  enable_deletion_protection = true
  enable_http2               = true
  enable_cross_zone_load_balancing = true

  # Target group
  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]

  target_groups = [
    {
      name_prefix      = "app-"
      backend_protocol = "HTTP"
      backend_port     = 8080
      target_type      = "instance"
      health_check = {
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 3
        interval            = 30
        path                = "/"
        matcher             = "200"
      }
    }
  ]

  tags = {
    Environment = "prod"
  }
}

# ============================================================================
# EXAMPLE 5: ASG Module (terraform-aws-modules/autoscaling/aws)
# ============================================================================

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 7.0"

  name            = "prod-asg"
  use_name_prefix = true

  # Launch template
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  # VPC configuration
  vpc_zone_identifier = module.vpc_public.private_subnets
  security_groups     = [module.app_security_group.security_group_id]

  # Scaling configuration
  min_size         = 2
  max_size         = 6
  desired_capacity = 3
  health_check_type = "ELB"
  health_check_grace_period = 300

  # Target group attachment
  target_group_arns = module.alb.target_group_arns

  # Termination policies
  termination_policies = [
    "OldestLaunchConfiguration",
    "Default"
  ]

  tag_specifications = [
    {
      resource_type = "instance"
      tags = {
        Environment = "prod"
        ManagedBy   = "ASG"
      }
    }
  ]
}

# ============================================================================
# EXAMPLE 6: SNS and SQS Modules (terraform-aws-modules)
# ============================================================================

module "sns_topic" {
  source  = "terraform-aws-modules/sns/aws"
  version = "~> 6.0"

  name       = "app-notifications"
  display_name = "Application Notifications"

  # Encryption
  kms_master_key_id = aws_kms_key.sns.id

  tags = {
    Environment = "prod"
  }
}

module "sqs_queue" {
  source  = "terraform-aws-modules/sqs/aws"
  version = "~> 4.0"

  name                      = "app-queue"
  visibility_timeout_seconds = 300
  message_retention_seconds  = 1209600  # 14 days

  # Encryption
  kms_master_key_id = aws_kms_key.sqs.id

  tags = {
    Environment = "prod"
  }
}

# ============================================================================
# SUPPORTING RESOURCES
# ============================================================================

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_key" "sqs" {
  description             = "KMS key for SQS"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

# ============================================================================
# OUTPUTS
# ============================================================================

output "vpc_id" {
  value = module.vpc_public.vpc_id
}

output "alb_dns_name" {
  value = module.alb.load_balancer_dns_name
}

output "rds_endpoint" {
  value = module.rds_postgres.db_instance_endpoint
}

output "asg_name" {
  value = module.asg.autoscaling_group_name
}

# ============================================================================
# PUBLIC REGISTRY MODULE GUIDELINES
# ============================================================================

# 1. WHERE TO FIND MODULES
#    - https://registry.terraform.io/
#    - Search by provider (aws, azure, gcp)
#    - Filter by verified and official modules

# 2. HOW TO CHOOSE MODULES
#    - Look at module rating/downloads
#    - Check maintenance (recently updated?)
#    - Review documentation
#    - Check GitHub (issues, PRs, activity)

# 3. VERSIONING
#    - Always pin major version: version = "~> 5.0"
#    - Allows minor/patch updates
#    - Prevents breaking changes

# 4. MODULE DOCUMENTATION
#    - Read module README in Registry
#    - Check inputs and outputs
#    - Review examples
#    - Understand module architecture

# 5. POPULAR AWS MODULES
#    - terraform-aws-modules/vpc/aws: VPC and subnets
#    - terraform-aws-modules/security-group/aws: Security groups
#    - terraform-aws-modules/rds/aws: RDS databases
#    - terraform-aws-modules/alb/aws: Application Load Balancer
#    - terraform-aws-modules/autoscaling/aws: Auto Scaling Groups
#    - terraform-aws-modules/sns/aws: SNS topics
#    - terraform-aws-modules/sqs/aws: SQS queues

# 6. BENEFITS OF PUBLIC MODULES
#    - Battle-tested and maintained
#    - Best practices built-in
#    - Saves development time
#    - Community-driven improvements
#    - Security updates

# 7. RISKS AND CONSIDERATIONS
#    - Dependency on third party
#    - May not fit all use cases
#    - Version upgrades may require changes
#    - Documentation may be incomplete

# 8. PRIVATE REGISTRY
#    - Terraform Cloud/Enterprise
#    - Host company-standard modules
#    - Control over versions
#    - Internal governance

# ============================================================================
