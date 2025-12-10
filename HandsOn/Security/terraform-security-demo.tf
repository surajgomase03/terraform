# Terraform Security Demo
# Demonstrates security best practices and common vulnerabilities

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # ✓ GOOD: Encrypt state at rest
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = "us-east-1"

  # ✓ GOOD: Default tags for consistency
  default_tags {
    tags = {
      ManagedBy      = "Terraform"
      SecurityScan   = "Required"
      ComplianceLevel = "High"
    }
  }
}

# ============================================================================
# SECURITY ANTI-PATTERNS AND FIXES
# ============================================================================

# ============================================================================
# VULNERABILITY 1: UNRESTRICTED SECURITY GROUP
# ============================================================================

# ✗ BAD: Open to entire internet
resource "aws_security_group" "bad_example_1" {
  name        = "bad-sg"
  description = "Bad security group"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # SSH open to world!
  }

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Database open to world!
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ✓ GOOD: Restricted to specific CIDRs
resource "aws_security_group" "good_example_1" {
  name        = "good-sg"
  description = "Secure security group"
  vpc_id      = aws_vpc.main.id

  # SSH only from bastion host
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  # Database only from app servers
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  # Allow outbound only to required services
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTPS outbound
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]  # DNS
  }
}

# ============================================================================
# VULNERABILITY 2: UNENCRYPTED DATABASE
# ============================================================================

# ✗ BAD: No encryption
resource "aws_db_instance" "bad_database" {
  identifier       = "prod-db"
  engine           = "postgres"
  instance_class   = "db.t3.micro"
  allocated_storage = 20
  # storage_encrypted = false  # Default: unencrypted!
  publicly_accessible = true  # Database open to internet!
}

# ✓ GOOD: Encrypted, not public
resource "aws_db_instance" "good_database" {
  identifier            = "prod-db"
  engine                = "postgres"
  instance_class        = "db.t3.micro"
  allocated_storage     = 20
  storage_encrypted     = true  # Encrypt at rest
  kms_key_id            = aws_kms_key.rds.arn  # Use customer-managed key
  publicly_accessible   = false  # Not accessible from internet
  skip_final_snapshot   = false  # Keep backup
  backup_retention_period = 30  # Keep backups
  
  # Credentials from Secrets Manager (not in code)
  # username = var.db_username
  # password = random_password.db.result
  
  multi_az = true  # High availability
}

# ============================================================================
# VULNERABILITY 3: S3 BUCKET MISCONFIGURATION
# ============================================================================

# ✗ BAD: Public S3 bucket
resource "aws_s3_bucket" "bad_bucket" {
  bucket = "my-bad-public-bucket"
}

resource "aws_s3_bucket_public_access_block" "bad_bucket" {
  bucket = aws_s3_bucket.bad_bucket.id

  block_public_acls       = false  # Allows public ACLs
  block_public_policy     = false  # Allows public policy
  ignore_public_acls      = false  # Doesn't ignore public ACLs
  restrict_public_buckets = false  # Allows public access
}

# ✓ GOOD: Private S3 bucket
resource "aws_s3_bucket" "good_bucket" {
  bucket = "my-good-private-bucket"
}

resource "aws_s3_bucket_public_access_block" "good_bucket" {
  bucket = aws_s3_bucket.good_bucket.id

  block_public_acls       = true  # Block all public ACLs
  block_public_policy     = true  # Block public policy
  ignore_public_acls      = true  # Ignore any public ACLs
  restrict_public_buckets = true  # Restrict public access
}

# Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "good_bucket" {
  bucket = aws_s3_bucket.good_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

# Versioning
resource "aws_s3_bucket_versioning" "good_bucket" {
  bucket = aws_s3_bucket.good_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Logging
resource "aws_s3_bucket_logging" "good_bucket" {
  bucket = aws_s3_bucket.good_bucket.id

  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "s3-access-logs/"
}

# ============================================================================
# VULNERABILITY 4: HARDCODED SECRETS
# ============================================================================

# ✗ BAD: Hardcoded password
resource "aws_db_instance" "bad_secrets" {
  identifier       = "bad-db"
  engine           = "postgres"
  master_username  = "admin"
  master_password  = "MySecretPassword123!"  # EXPOSED!
}

# ✓ GOOD: Use AWS Secrets Manager
resource "random_password" "db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "prod/db-password"
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_db_instance" "good_secrets" {
  identifier       = "good-db"
  engine           = "postgres"
  master_username  = "admin"
  master_password  = random_password.db.result  # Generated, not hardcoded
  
  # Application fetches from Secrets Manager at runtime
}

# ============================================================================
# VULNERABILITY 5: UNENCRYPTED TRANSPORT
# ============================================================================

# ✗ BAD: Allow insecure traffic
resource "aws_alb_listener" "bad_listener" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"  # Unencrypted

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ✓ GOOD: Enforce HTTPS
resource "aws_alb_listener" "good_listener_https" {
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"  # Encrypted
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# Redirect HTTP to HTTPS
resource "aws_alb_listener" "good_listener_http_redirect" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ============================================================================
# VULNERABILITY 6: OVERLY PERMISSIVE IAM POLICY
# ============================================================================

# ✗ BAD: Wildcard permissions
resource "aws_iam_role" "bad_role" {
  name = "bad-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "bad_policy" {
  name   = "bad-policy"
  role   = aws_iam_role.bad_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"  # All actions
        Resource = "*"  # All resources
      }
    ]
  })
}

# ✓ GOOD: Least privilege
resource "aws_iam_role" "good_role" {
  name = "good-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "good_policy" {
  name   = "good-policy"
  role   = aws_iam_role.good_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::my-bucket/app/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ============================================================================
# SUPPORTING RESOURCES
# ============================================================================

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_security_group" "bastion" {
  name = "bastion"
  vpc_id = aws_vpc.main.id
}

resource "aws_security_group" "app" {
  name = "app"
  vpc_id = aws_vpc.main.id
}

resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3"
  deletion_window_in_days = 10
  enable_key_rotation     = true
}

resource "aws_s3_bucket" "logs" {
  bucket = "my-log-bucket"
}

resource "aws_lb" "main" {
  name = "main-lb"
}

resource "aws_lb_target_group" "main" {
  name = "main-tg"
  port = 8080
  protocol = "HTTP"
  vpc_id = aws_vpc.main.id
}

resource "aws_acm_certificate" "main" {
  domain_name = "example.com"
  validation_method = "DNS"
}
