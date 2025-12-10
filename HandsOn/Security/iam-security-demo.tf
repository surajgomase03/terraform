# IAM Security Demo
# Demonstrates AWS IAM security best practices with Terraform

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
# IAM SECURITY PRINCIPLE 1: LEAST PRIVILEGE (MOST IMPORTANT)
# ============================================================================

# ✗ BAD: Admin access to everything
resource "aws_iam_role" "admin_role" {
  name = "admin-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "admin_policy" {
  name = "admin-policy"
  role = aws_iam_role.admin_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "*"  # ✗ CRITICAL: Wildcard access
        Resource = "*"
      }
    ]
  })
}

# ✓ GOOD: Least privilege role for specific task
resource "aws_iam_role" "app_role" {
  name = "app-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "app_policy" {
  name = "app-policy"
  role = aws_iam_role.app_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Only specific S3 permissions
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::my-app-bucket",
          "arn:aws:s3:::my-app-bucket/*"
        ]
      },
      {
        # Only specific CloudWatch permissions
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:us-east-1:*:log-group:/aws/app/*"
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 2: ROLE-BASED ACCESS CONTROL (RBAC)
# ============================================================================

# Developer role (limited permissions)
resource "aws_iam_role" "developer_role" {
  name = "developer-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "unique-external-id"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "developer_policy" {
  name = "developer-policy"
  role = aws_iam_role.developer_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "logs:Describe*",
          "logs:Get*",
          "logs:List*"
        ]
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# DevOps role (more permissions)
resource "aws_iam_role" "devops_role" {
  name = "devops-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "devops_policy" {
  name = "devops-policy"
  role = aws_iam_role.devops_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "elasticloadbalancing:*",
          "autoscaling:*",
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# Security Administrator role
resource "aws_iam_role" "security_admin_role" {
  name = "security-admin-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = ["203.0.113.0/24"]  # Corporate network only
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "security_admin_policy" {
  name = "security-admin-policy"
  role = aws_iam_role.security_admin_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "iam:*",
          "kms:*",
          "secretsmanager:*",
          "cloudtrail:*",
          "guardduty:*",
          "securityhub:*"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 3: RESOURCE-BASED POLICIES
# ============================================================================

# S3 bucket with resource-based policy
resource "aws_s3_bucket" "shared_data" {
  bucket = "shared-data-bucket-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_policy" "shared_data" {
  bucket = aws_s3_bucket.shared_data.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowAppRoleReadWrite"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.app_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.shared_data.arn,
          "${aws_s3_bucket.shared_data.arn}/*"
        ]
      },
      {
        Sid    = "DenyInsecureTransport"
        Effect = "Deny"
        Principal = "*"
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.shared_data.arn,
          "${aws_s3_bucket.shared_data.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 4: POLICY CONDITIONS
# ============================================================================

# Policy with detailed conditions
resource "aws_iam_role" "conditional_role" {
  name = "conditional-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/developer"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "unique-id"
          }
          IpAddress = {
            "aws:SourceIp" = [
              "203.0.113.0/24",
              "198.51.100.0/24"
            ]
          }
          DateGreaterThan = {
            "aws:CurrentTime" = "2024-01-01T00:00:00Z"
          }
          DateLessThan = {
            "aws:CurrentTime" = "2025-01-01T00:00:00Z"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "conditional_policy" {
  name = "conditional-policy"
  role = aws_iam_role.conditional_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:TerminateInstances",
          "ec2:StopInstances"
        ]
        Resource = "arn:aws:ec2:us-east-1:*:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Environment" = "dev"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = [
          "ec2:TerminateInstances",
          "ec2:StopInstances"
        ]
        Resource = "arn:aws:ec2:us-east-1:*:instance/*"
        Condition = {
          StringEquals = {
            "ec2:ResourceTag/Environment" = "prod"
          }
        }
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 5: SERVICE ROLES
# ============================================================================

# Lambda execution role
resource "aws_iam_role" "lambda_role" {
  name = "lambda-role"
  
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

resource "aws_iam_role_policy" "lambda_policy" {
  name = "lambda-policy"
  role = aws_iam_role.lambda_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::my-bucket/*"
      }
    ]
  })
}

# EC2 instance profile
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy" "ec2_policy" {
  name = "ec2-policy"
  role = aws_iam_role.ec2_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:AcknowledgeMessage",
          "ssmmessages:GetEndpoint",
          "ssmmessages:GetMessages",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 6: CROSS-ACCOUNT ACCESS
# ============================================================================

# Role for trusted account to assume
resource "aws_iam_role" "cross_account_role" {
  name = "cross-account-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::TRUSTED-ACCOUNT-ID:root"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "unique-external-id-${random_id.external_id.hex}"
          }
        }
      }
    ]
  })
}

resource "random_id" "external_id" {
  byte_length = 16
}

resource "aws_iam_role_policy" "cross_account_policy" {
  name = "cross-account-policy"
  role = aws_iam_role.cross_account_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::shared-bucket"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::shared-bucket/*"
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 7: DENY POLICIES (EXPLICIT DENY)
# ============================================================================

# Explicit deny overrides allows
resource "aws_iam_role_policy" "security_guardrails" {
  name = "security-guardrails"
  role = aws_iam_role.app_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Deny removing security group rules
        Effect = "Deny"
        Action = [
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress"
        ]
        Resource = "*"
      },
      {
        # Deny disabling CloudTrail
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail"
        ]
        Resource = "*"
      },
      {
        # Deny modifying IAM roles
        Effect = "Deny"
        Action = [
          "iam:PutUserPolicy",
          "iam:PutRolePolicy",
          "iam:AttachUserPolicy",
          "iam:AttachRolePolicy",
          "iam:UpdateAssumeRolePolicy",
          "iam:UpdateTrustPolicy"
        ]
        Resource = "*"
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 8: MFA FOR HUMAN USERS
# ============================================================================

# IAM user with MFA requirement
resource "aws_iam_user" "developer" {
  name = "john-developer"
  tags = {
    Department = "Engineering"
  }
}

resource "aws_iam_user_policy" "developer_policy" {
  name = "developer-policy"
  user = aws_iam_user.developer.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # Allow everything except for sensitive operations
        Effect = "Allow"
        Action = [
          "ec2:*",
          "s3:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        # Require MFA for sensitive operations
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
        Condition = {
          BoolIfExists = {
            "aws:MultiFactorAuthPresent" = "false"
          }
        }
      }
    ]
  })
}

# ============================================================================
# IAM SECURITY PRINCIPLE 9: SESSION DURATION LIMITS
# ============================================================================

# Role with maximum session duration
resource "aws_iam_role" "temporary_access_role" {
  name               = "temporary-access-role"
  max_session_duration = 3600  # 1 hour maximum
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/support-engineer"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# ============================================================================
# DATA SOURCES
# ============================================================================

data "aws_caller_identity" "current" {}

# ============================================================================
# OUTPUTS
# ============================================================================

output "app_role_arn" {
  value       = aws_iam_role.app_role.arn
  description = "ARN of least privilege app role"
}

output "developer_role_arn" {
  value       = aws_iam_role.developer_role.arn
  description = "ARN of developer role"
}

output "devops_role_arn" {
  value       = aws_iam_role.devops_role.arn
  description = "ARN of DevOps role"
}

output "security_admin_role_arn" {
  value       = aws_iam_role.security_admin_role.arn
  description = "ARN of security admin role"
}

output "cross_account_external_id" {
  value       = random_id.external_id.hex
  description = "External ID for cross-account access"
  sensitive   = true
}

# ============================================================================
# IAM SECURITY BEST PRACTICES SUMMARY
# ============================================================================

# 1. LEAST PRIVILEGE
#    - Grant only required permissions
#    - Use specific actions, not wildcards
#    - Restrict resources to specific ARNs
#    - Review permissions regularly

# 2. SEPARATE ROLES BY FUNCTION
#    - Developer role (limited)
#    - DevOps role (moderate)
#    - Security admin role (full security)
#    - Application roles (specific to task)

# 3. USE CONDITIONS
#    - IP address restrictions
#    - Time-based restrictions
#    - Resource tags
#    - MFA requirement

# 4. EXPLICIT DENY
#    - Use deny policies as guardrails
#    - Deny overrides allow
#    - Prevents accidental permission granting

# 5. SERVICE ROLES
#    - Use for applications/services
#    - Trust only needed AWS services
#    - Limit to specific resources

# 6. EXTERNAL ID FOR CROSS-ACCOUNT
#    - Always use external ID
#    - Changes reduce risk
#    - Prevents confused deputy problem

# 7. MFA FOR HUMANS
#    - Require MFA for sensitive operations
#    - Use hardware or app-based MFA
#    - Never allow programmatic MFA bypass

# 8. NO LONG-TERM CREDENTIALS
#    - Use temporary credentials (STS)
#    - Session duration limits
#    - Regular rotation

# 9. LEAST PRIVILEGE FOR ROOT ACCOUNT
#    - Don't use root access keys
#    - Enable MFA on root account
#    - Use CloudTrail to monitor
#    - Only for account recovery

# ============================================================================
