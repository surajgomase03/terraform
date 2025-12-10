# Terraform Security Best Practices Guide

## Executive Summary

This guide provides comprehensive security best practices for Terraform infrastructure code. Following these practices protects against vulnerabilities, misconfigurations, and compliance violations.

**Key Principles:**
1. **Security by Default** - Secure configurations first, not afterthought
2. **Encryption Everywhere** - Data at rest and in transit
3. **Secrets Management** - Never hardcode credentials
4. **Least Privilege** - Only needed permissions
5. **Audit Everything** - CloudTrail, VPC Flow Logs, application logs
6. **Automated Scanning** - tfsec, Trivy, checkov in CI/CD
7. **Network Security** - Security groups, NACLs, private subnets
8. **Access Control** - IAM roles, conditions, resource-based policies

---

## Table of Contents

1. [Secrets Management](#1-secrets-management)
2. [Encryption](#2-encryption)
3. [IAM Security](#3-iam-security)
4. [Network Security](#4-network-security)
5. [Data Protection](#5-data-protection)
6. [Audit & Compliance](#6-audit--compliance)
7. [Scanning & Detection](#7-scanning--detection)
8. [State Management](#8-state-management)
9. [Code Review & CI/CD](#9-code-review--cicd)
10. [Incident Response](#10-incident-response)

---

## 1. Secrets Management

### ✗ Bad Pattern
```hcl
resource "aws_db_instance" "bad" {
  password = "MyPassword123!"  # Never hardcode!
}

output "api_key" {
  value = "sk_live_xyz123"  # Exposed in logs
}
```

### ✓ Good Pattern

**Option 1: AWS Secrets Manager**
```hcl
resource "random_password" "db" {
  length  = 32
  special = true
}

resource "aws_secretsmanager_secret" "db_password" {
  name = "prod/database-password"
  # Encrypted with KMS by default
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = random_password.db.result
}

resource "aws_db_instance" "good" {
  password = random_password.db.result
  # KMS encrypted secret stored separately
}
```

**Option 2: AWS Systems Manager Parameter Store**
```hcl
resource "aws_ssm_parameter" "db_password" {
  name  = "/prod/database-password"
  type  = "SecureString"  # AES-256 encrypted
  value = random_password.db.result
  
  tags = {
    Environment = "prod"
    Encrypted   = "true"
  }
}
```

**Option 3: HashiCorp Vault (Multi-cloud)**
```hcl
resource "vault_generic_secret" "db_password" {
  path      = "secret/prod/database"
  data_json = jsonencode({
    password = random_password.db.result
  })
}

data "vault_generic_secret" "db_password" {
  path = vault_generic_secret.db_password.path
}
```

### Best Practices
- [ ] Use Secrets Manager or Parameter Store
- [ ] Encrypt secrets with KMS
- [ ] Rotate credentials regularly (30-90 days)
- [ ] Use Vault for multi-cloud
- [ ] Never commit secrets to Git
- [ ] Use `.gitignore` for credential files
- [ ] Mark outputs as `sensitive = true`
- [ ] Use Terraform Cloud for safe secrets handling
- [ ] Implement secret scanning in CI/CD
- [ ] Audit secret access with CloudTrail

### Secret Scanning in Git
```bash
# Install git-secrets
brew install git-secrets

# Add AWS patterns
git secrets --register-aws

# Scan before commit
git secrets --scan

# Configure for all commits
git secrets --install
```

---

## 2. Encryption

### ✗ Bad Pattern
```hcl
# Unencrypted database
resource "aws_db_instance" "bad" {
  storage_encrypted = false  # Vulnerable!
}

# Unencrypted S3 bucket
resource "aws_s3_bucket" "bad" {
  bucket = "unencrypted-bucket"
  # No encryption configuration
}

# Unencrypted EBS volume
resource "aws_ebs_volume" "bad" {
  encrypted = false  # Vulnerable!
}
```

### ✓ Good Pattern

**Encrypted RDS**
```hcl
resource "aws_kms_key" "rds" {
  description             = "KMS key for RDS encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_db_instance" "good" {
  storage_encrypted = true
  kms_key_id        = aws_kms_key.rds.arn
  # All data encrypted at rest
  # Backups encrypted
  # Replicas encrypted
}
```

**Encrypted S3**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "good" {
  bucket = aws_s3_bucket.my_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true  # Save cost
  }
}

resource "aws_s3_bucket_public_access_block" "good" {
  bucket = aws_s3_bucket.my_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Encrypted EBS**
```hcl
resource "aws_ebs_volume" "good" {
  availability_zone = "us-east-1a"
  size              = 100
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn
}
```

**Encrypted CloudWatch Logs**
```hcl
resource "aws_cloudwatch_log_group" "good" {
  name       = "/prod/application"
  kms_key_id = aws_kms_key.logs.arn  # Encrypt logs
  retention_in_days = 30
}
```

**Encrypted Terraform State**
```hcl
terraform {
  backend "s3" {
    bucket             = "terraform-state"
    key                = "prod/terraform.tfstate"
    region             = "us-east-1"
    encrypt            = true  # Enable encryption
    kms_key_id         = "arn:aws:kms:..."  # Custom key
    dynamodb_table     = "terraform-locks"
  }
}
```

### Encryption Checklist
- [ ] RDS: `storage_encrypted = true`
- [ ] S3: Server-side encryption (AES-256 or KMS)
- [ ] EBS: `encrypted = true`
- [ ] CloudWatch Logs: `kms_key_id` specified
- [ ] Terraform State: S3 bucket encryption + KMS
- [ ] SNS/SQS: KMS encryption enabled
- [ ] Lambda environment: Encrypted at rest
- [ ] DynamoDB: Point-in-time recovery
- [ ] Backup: KMS encrypted backups
- [ ] TLS: All data in transit

---

## 3. IAM Security

### ✗ Bad Pattern
```hcl
# Admin access
resource "aws_iam_policy" "bad" {
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "*"  # Wildcard access!
      Resource = "*"
    }]
  })
}

# Hardcoded credentials
variable "aws_access_key" {
  default = "AKIA..."  # Never do this!
}

# No trust policy restrictions
resource "aws_iam_role" "bad" {
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "*" }  # Anyone can assume!
      Action    = "sts:AssumeRole"
    }]
  })
}
```

### ✓ Good Pattern

**Least Privilege Permissions**
```hcl
resource "aws_iam_role" "app" {
  name = "app-role"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "app" {
  role = aws_iam_role.app.name
  
  policy = jsonencode({
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::app-bucket",
          "arn:aws:s3:::app-bucket/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/app/*"
      }
    ]
  })
}
```

**Cross-Account with External ID**
```hcl
resource "aws_iam_role" "cross_account" {
  name = "cross-account-role"
  
  assume_role_policy = jsonencode({
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::OTHER-ACCOUNT:root" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "unique-random-string"
        }
      }
    }]
  })
  
  max_session_duration = 3600  # 1 hour max
}
```

**Permission Boundary**
```hcl
resource "aws_iam_role" "permission_boundary" {
  # Maximum permissions allowed
}

resource "aws_iam_role_policy" "boundary" {
  role = aws_iam_role.permission_boundary.name
  
  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Action = ["s3:*", "logs:*"]
      Resource = "*"
    }]
  })
}

# Actual role can't exceed boundary
resource "aws_iam_role" "app" {
  name                   = "app"
  permissions_boundary   = aws_iam_role.permission_boundary.arn
}
```

**Explicit Deny for Guardrails**
```hcl
resource "aws_iam_role_policy" "guardrails" {
  role = aws_iam_role.app.name
  
  policy = jsonencode({
    Statement = [
      {
        # Prevent privilege escalation
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*"
        ]
        Resource = "*"
      },
      {
        # Prevent disabling security
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "ec2:RevokeSecurityGroupIngress"
        ]
        Resource = "*"
      }
    ]
  })
}
```

### IAM Checklist
- [ ] No wildcard actions (s3:*, ec2:*)
- [ ] No wildcard resources (*)
- [ ] Explicit deny policies for guardrails
- [ ] Permission boundaries for delegation
- [ ] Role-based access (not users)
- [ ] Trust policies restrict principals
- [ ] Conditions: IP, MFA, tags, time
- [ ] Cross-account uses external ID
- [ ] Session duration limits (max 1 hour)
- [ ] Regular policy reviews (quarterly)
- [ ] No hardcoded credentials
- [ ] Root account protected with MFA

---

## 4. Network Security

### ✗ Bad Pattern
```hcl
# Open security group
resource "aws_security_group" "bad" {
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Open to world!
  }
}

# Public database
resource "aws_db_instance" "bad" {
  publicly_accessible = true  # Dangerous!
}

# Unencrypted API
resource "aws_lb" "bad" {
  # No HTTPS enforcement
}
```

### ✓ Good Pattern

**Restricted Security Groups**
```hcl
resource "aws_security_group" "web" {
  name = "web-sg"
  vpc_id = aws_vpc.main.id

  # HTTPS only
  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # HTTP redirect
  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  # SSH from bastion only
  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]  # Outbound usually OK
  }
}

resource "aws_security_group" "database" {
  # Database only accessible from app
  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]  # Only from web tier
  }
}
```

**Private Database**
```hcl
resource "aws_db_instance" "prod" {
  publicly_accessible = false  # Private
  
  db_subnet_group_name = aws_db_subnet_group.private.name
  
  # Security group allows only app access
  vpc_security_group_ids = [aws_security_group.database.id]
  
  storage_encrypted = true
}
```

**HTTPS-Only Load Balancer**
```hcl
resource "aws_lb" "app" {
  name               = "app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = aws_subnet.public[*].id
}

# Force HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}
```

**VPC Flow Logs**
```hcl
resource "aws_flow_log" "main" {
  iam_role_arn = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type = "ALL"
  vpc_id = aws_vpc.main.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name              = "/aws/vpc/flowlogs"
  retention_in_days = 30
  kms_key_id        = aws_kms_key.logs.arn
}
```

### Network Checklist
- [ ] Security groups: minimum required ports
- [ ] No database access from internet
- [ ] Private subnets for databases
- [ ] HTTPS/TLS for all traffic
- [ ] HTTP redirects to HTTPS
- [ ] VPC Flow Logs enabled
- [ ] NACLs restrict traffic (additional layer)
- [ ] Security groups restrict between tiers
- [ ] Bastion host for SSH access
- [ ] VPN/private link for inter-vpc traffic
- [ ] DDoS protection (AWS Shield, WAF)

---

## 5. Data Protection

### Backup & Recovery
```hcl
# RDS backup
resource "aws_db_instance" "prod" {
  backup_retention_period = 30  # 30 days
  backup_window           = "03:00-04:00"  # Off-peak
  copy_tags_to_snapshot   = true
  
  skip_final_snapshot       = false
  final_snapshot_identifier = "prod-backup-${formatdate("YYYY-MM-DD-hhmm", timestamp())}"
}

# S3 versioning and lifecycle
resource "aws_s3_bucket_versioning" "prod" {
  bucket = aws_s3_bucket.prod.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "prod" {
  bucket = aws_s3_bucket.prod.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
  }
}
```

### Data Residency & Compliance
```hcl
# Ensure data stays in region
resource "aws_s3_bucket" "prod" {
  bucket = "prod-data"
}

# Block cross-region replication (compliance)
resource "aws_s3_bucket_replication_configuration" "not_allowed" {
  # Not configured - data stays in region
}

# Compliance: Specific region only
provider "aws" {
  region = "us-east-1"
  
  # Prevent accidental multi-region deployments
}
```

---

## 6. Audit & Compliance

### CloudTrail
```hcl
resource "aws_s3_bucket" "cloudtrail" {
  bucket = "cloudtrail-logs-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_policy" "cloudtrail" {
  bucket = aws_s3_bucket.cloudtrail.id

  policy = jsonencode({
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action = "s3:PutObject"
      Resource = "${aws_s3_bucket.cloudtrail.arn}/*"
    }]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "main"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true  # Detect tampering
}
```

### Config
```hcl
resource "aws_config_configuration_aggregator" "main" {
  name = "main"

  account_aggregation_sources {
    account_ids = [data.aws_caller_identity.current.account_id]
  }
}

resource "aws_config_config_rule" "s3_encryption" {
  name = "s3-encryption"

  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_SERVER_SIDE_ENCRYPTION_ENABLED"
  }
}
```

### Monitoring & Alerts
```hcl
resource "aws_cloudwatch_metric_alarm" "unauthorized_calls" {
  alarm_name = "unauthorized-api-calls"
  
  metric_name  = "UnauthorizedOperationCount"
  namespace    = "CloudTrailMetrics"
  statistic    = "Sum"
  period       = 300
  threshold    = 1
  
  alarm_actions = [aws_sns_topic.security.arn]
}
```

---

## 7. Scanning & Detection

### Pre-commit Scanning
```bash
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/aquasecurity/tfsec
    rev: v1.25.0
    hooks:
      - id: tfsec

  - repo: https://github.com/terraform-linters/tflint
    rev: v0.47.0
    hooks:
      - id: tflint
```

### CI/CD Scanning
```yaml
# GitHub Actions
name: Security Scan

on: [pull_request, push]

jobs:
  tfsec:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/tfsec-action@latest
        with:
          minimum_severity: HIGH

  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'HIGH,CRITICAL'
```

---

## 8. State Management

### Secure State Storage
```hcl
terraform {
  backend "s3" {
    bucket             = "terraform-state"
    key                = "prod/terraform.tfstate"
    region             = "us-east-1"
    encrypt            = true
    kms_key_id         = "arn:aws:kms:..."
    dynamodb_table     = "terraform-locks"
    
    # Enable versioning at bucket level
    # Enable MFA delete
    # Enable access logging
  }
}
```

### State File Protection
```hcl
# S3 bucket security
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-state"
}

resource "aws_s3_bucket_encryption" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Enabled"  # Require MFA to delete
  }
}

# DynamoDB state locking
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"
  
  encryption_specifications {
    enabled = true
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

---

## 9. Code Review & CI/CD

### Code Review Checklist
- [ ] Least privilege permissions
- [ ] No hardcoded secrets/passwords
- [ ] Encryption enabled for data storage
- [ ] Security groups properly restricted
- [ ] Public access blocked where needed
- [ ] Logging/audit enabled
- [ ] Backups configured
- [ ] Tags/labels applied
- [ ] Comments document security decisions
- [ ] No deprecated resource types

### CI/CD Security Gates
```yaml
name: Terraform Security Pipeline

on: [pull_request]

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init -backend=false
      - run: terraform validate

  fmt:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform fmt -check -recursive

  tfsec:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/tfsec-action@latest
        with:
          minimum_severity: HIGH

  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'HIGH,CRITICAL'

  checkov:
    runs-on: ubuntu-latest
    steps:
      - uses: bridgecrewio/checkov-action@master
        with:
          framework: terraform
          quiet: true
          compact: true
          skip_check: CKV_AWS_1

  plan:
    runs-on: ubuntu-latest
    needs: [validate, fmt, tfsec, trivy]
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform plan -no-color
```

---

## 10. Incident Response

### Emergency Procedures

**Compromised Credentials:**
1. [ ] Immediately revoke credentials
2. [ ] Check CloudTrail for suspicious activity
3. [ ] Assess blast radius
4. [ ] Notify security team
5. [ ] Generate new credentials
6. [ ] Update documentation

```bash
# Revoke access key
aws iam delete-access-key --access-key-id AKIAIOSFODNN7EXAMPLE

# Check activity
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=AccessKeyId,AttributeValue=AKIAIOSFODNN7EXAMPLE
```

**Unauthorized Resource Creation:**
1. [ ] Document what was created
2. [ ] Capture logs before deletion
3. [ ] Delete/stop unauthorized resources
4. [ ] Check related resources
5. [ ] Review IAM permissions
6. [ ] Update deny policies

```bash
# List resources by creator
aws resourcegroupstaggingapi get-resources \
  --tag-filter-list Key=CreatedBy,Values=compromised-role
```

---

## Security Maturity Model

| Level | Practices | Tools |
|-------|-----------|-------|
| **L1: Basic** | Encryption, basic IAM | terraform validate |
| **L2: Operational** | Logging, monitoring, scanning | tfsec, CloudTrail |
| **L3: Advanced** | Policy enforcement, automation | Vault, checkov, Policy as Code |
| **L4: Excellence** | Zero-trust, continuous compliance | sentinel, custom scanning |

---

## Compliance Frameworks

**Terraform helps with:**
- [ ] **CIS AWS Foundations:** Best practices
- [ ] **HIPAA:** Encryption, audit, access control
- [ ] **PCI-DSS:** Encryption, network isolation, audit
- [ ] **SOC 2:** Logging, monitoring, access controls
- [ ] **ISO 27001:** Information security

---

## Resources

- [AWS Security Best Practices](https://aws.amazon.com/architecture/security-identity-compliance/)
- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [tfsec](https://aquasecurity.github.io/tfsec/)
- [Trivy](https://aquasecurity.github.io/trivy/)
- [Checkov](https://www.checkov.io/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [OWASP Cloud Security](https://owasp.org/www-project-cloud-security/)

---

## Final Checklist

**Before Production:**
- [ ] Security scanning passes (tfsec, trivy)
- [ ] Code review approved
- [ ] Encryption enabled for all data
- [ ] Least privilege IAM policies
- [ ] Logging/CloudTrail enabled
- [ ] Backups configured
- [ ] Secrets in Secrets Manager/Vault
- [ ] Network isolation verified
- [ ] Monitoring/alerting set up
- [ ] Disaster recovery tested
- [ ] Documentation complete
- [ ] Compliance requirements met

