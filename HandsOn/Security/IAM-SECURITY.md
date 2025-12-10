# IAM Security Interview Guide

## Q1: What is the principle of least privilege and why is it critical?

**Answer:**
Least privilege means granting only the minimum permissions needed to perform a task. It's the foundation of cloud security.

**Why it's critical:**
- **Minimize blast radius:** If credentials are compromised, attacker has limited access
- **Compliance:** Required by HIPAA, PCI-DSS, SOC 2
- **Accountability:** Easier to audit who did what
- **Prevention:** Blocks accidental modifications
- **Defense-in-depth:** Multiple layers of security controls

**How to implement:**
```hcl
# ✗ BAD: Admin access to everything
Effect = "Allow"
Action = "*"
Resource = "*"

# ✓ GOOD: Only required permissions
Effect = "Allow"
Action = [
  "s3:GetObject",
  "s3:ListBucket"
]
Resource = [
  "arn:aws:s3:::my-bucket",
  "arn:aws:s3:::my-bucket/*"
]
```

**Least privilege checklist:**
- [ ] Specific actions (not wildcards)
- [ ] Specific resources (not *)
- [ ] Specific principals (not *)
- [ ] Time-limited access
- [ ] Conditions (IP, MFA, tags)
- [ ] Regular reviews (quarterly)

---

## Q2: What are the different types of IAM policies?

**Answer:**

**IAM policy types:**

| Type | Purpose | Scope | Example |
|------|---------|-------|---------|
| **Identity-based** | Attached to users/roles/groups | Attached to principal | Allow S3 access |
| **Resource-based** | Attached to resources | S3, KMS, SQS, SNS | Bucket policy |
| **Permission boundary** | Maximum permissions | Limit delegation | Max EC2 permissions |
| **Session policy** | Temporary credentials | STS sessions | Limited time access |
| **Trust policy** | Who can assume role | Role assumption | Only EC2 service |

**Identity-based policy (attached to role):**
```hcl
resource "aws_iam_role_policy" "app_policy" {
  role = aws_iam_role.app.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = "s3:GetObject"
      Resource = "arn:aws:s3:::bucket/*"
    }]
  })
}
```

**Resource-based policy (attached to resource):**
```hcl
resource "aws_s3_bucket_policy" "bucket_policy" {
  bucket = aws_s3_bucket.my_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = aws_iam_role.app.arn
      }
      Action = "s3:GetObject"
      Resource = "${aws_s3_bucket.my_bucket.arn}/*"
    }]
  })
}
```

**Trust policy (assume role policy):**
```hcl
resource "aws_iam_role" "app_role" {
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"  # Only EC2 can assume
      }
      Action = "sts:AssumeRole"
    }]
  })
}
```

---

## Q3: What is a trust policy and why is it important?

**Answer:**
A trust policy (assume role policy) defines who can assume an IAM role. It's separate from permissions.

**Trust policy structure:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"  // Who can assume
      },
      "Action": "sts:AssumeRole"       // What they can do
    }
  ]
}
```

**Types of principals:**

| Principal | Example | Use Case |
|-----------|---------|----------|
| **AWS Service** | `"Service": "ec2.amazonaws.com"` | EC2, Lambda, RDS |
| **AWS Account** | `"AWS": "arn:aws:iam::123456789:root"` | Cross-account access |
| **IAM User** | `"AWS": "arn:aws:iam::123456789:user/john"` | User delegation |
| **IAM Role** | `"AWS": "arn:aws:iam::123456789:role/admin"` | Role chaining |
| **Federated User** | `"Federated": "arn:aws:iam::123456789:saml-provider/ExampleProvider"` | External identity |

**Common trust policies:**

**For EC2:**
```json
{
  "Principal": {
    "Service": "ec2.amazonaws.com"
  }
}
```

**For Lambda:**
```json
{
  "Principal": {
    "Service": "lambda.amazonaws.com"
  }
}
```

**Cross-account access (with external ID for security):**
```json
{
  "Principal": {
    "AWS": "arn:aws:iam::TRUSTING-ACCOUNT:root"
  },
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "unique-random-string"
    }
  }
}
```

---

## Q4: What is policy evaluation logic and how do permissions work?

**Answer:**
AWS uses specific evaluation logic to determine if an action is allowed.

**Policy evaluation decision tree:**

```
Request received
     ↓
Explicit Deny? → Return DENY
     ↓
Explicit Allow? → Return ALLOW (if conditions match)
     ↓
Implicit Deny → Return DENY (default)
```

**Key points:**
1. **Explicit Deny always wins** (overrides Allow)
2. **No explicit Allow = Deny** (default deny)
3. **All conditions must match** (AND logic)
4. **Multiple allows = Allow** (OR logic)

**Example evaluation:**

```json
// Identity policy: Allow S3 GetObject
{
  "Effect": "Allow",
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::bucket/*"
}

// Deny policy: Deny all deletion
{
  "Effect": "Deny",
  "Action": "s3:DeleteObject",
  "Resource": "*"
}

// Resource policy: Allow specific IAM role
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::123456789:role/app"
  },
  "Action": "s3:GetObject"
}
```

**Request: Can role/app do s3:GetObject on s3://bucket/file?**
- ✓ Identity policy allows: YES
- ✓ Resource policy allows for this role: YES
- ✓ No explicit deny: YES
- ✓ Result: ALLOW

---

## Q5: What is permission boundary and when do you use it?

**Answer:**
Permission boundary is a maximum permission filter applied to IAM users and roles.

**Use cases:**
- **Delegation control:** Prevent users from creating overly permissive roles
- **Compliance:** Enforce maximum permissions across organization
- **Self-service:** Let teams create their own roles safely

**How it works:**
```
Effective permissions = Identity policy ∩ Permission boundary
(Intersection - must be in both)
```

**Example:**
```hcl
# Permission boundary: Maximum what can be granted
resource "aws_iam_role" "permission_boundary" {
  name = "max-permissions"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "boundary" {
  role = aws_iam_role.permission_boundary.name
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:*",
        "logs:*"
      ]
      Resource = "*"
    }]
  })
}

# Actual role with less permissions
resource "aws_iam_role" "app_role" {
  name                   = "app-role"
  permissions_boundary   = aws_iam_role.permission_boundary.arn
  
  # Can only do what's in both boundary AND this policy
  # Even with wildcard actions, limited by boundary
}
```

**Boundary benefits:**
- ✓ Prevents privilege escalation
- ✓ Enforces guardrails
- ✓ Allows delegation safely
- ✓ Simplifies compliance

---

## Q6: How do you implement role-based access control (RBAC)?

**Answer:**
RBAC assigns permissions based on job role, not individual users.

**Steps to implement RBAC:**

**1. Define roles:**
```hcl
# Developer role
resource "aws_iam_role" "developer" {
  name = "developer"
}

# DevOps role
resource "aws_iam_role" "devops" {
  name = "devops"
}

# Security admin role
resource "aws_iam_role" "security_admin" {
  name = "security-admin"
}
```

**2. Create policies for each role:**
```hcl
# Developer: Read-only to EC2 and logs
resource "aws_iam_role_policy" "developer_policy" {
  role = aws_iam_role.developer.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:Describe*",
        "logs:Get*",
        "logs:Describe*"
      ]
      Resource = "*"
    }]
  })
}

# DevOps: Manage infrastructure
resource "aws_iam_role_policy" "devops_policy" {
  role = aws_iam_role.devops.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ec2:*",
        "autoscaling:*",
        "elasticloadbalancing:*"
      ]
      Resource = "*"
    }]
  })
}
```

**3. Assign users to roles:**
```bash
# User john is developer
aws iam add-user-to-group --user-name john --group-name developers

# User jane is devops
aws iam add-user-to-group --user-name jane --group-name devops
```

**4. Use assume role for temporary access:**
```bash
# Developer assumes developer role temporarily
aws sts assume-role \
  --role-arn arn:aws:iam::123456789:role/developer \
  --role-session-name john-session
```

**RBAC benefits:**
- ✓ Easier management at scale
- ✓ Consistent permissions
- ✓ Clear separation of duties
- ✓ Simpler audit trail

---

## Q7: What are policy conditions and how do you use them?

**Answer:**
Conditions are rules that must be true for permission to apply. They add fine-grained control.

**Common condition operators:**

| Operator | Use Case | Example |
|----------|----------|---------|
| **StringEquals** | Exact match | `"aws:username": "john"` |
| **StringLike** | Wildcard match | `"aws:username": "john*"` |
| **IpAddress** | Source IP | `"aws:SourceIp": "203.0.113.0/24"` |
| **DateGreaterThan** | Start time | `"aws:CurrentTime": "2024-01-01T00:00:00Z"` |
| **DateLessThan** | End time | `"aws:CurrentTime": "2024-12-31T23:59:59Z"` |
| **Bool** | True/False | `"aws:MultiFactorAuthPresent": "true"` |
| **NumericGreaterThan** | Numeric comparison | `"aws:SessionDuration": ">3600"` |

**Examples:**

**IP restriction:**
```json
{
  "Effect": "Allow",
  "Action": "s3:*",
  "Resource": "*",
  "Condition": {
    "IpAddress": {
      "aws:SourceIp": "203.0.113.0/24"
    }
  }
}
```

**MFA requirement:**
```json
{
  "Effect": "Allow",
  "Action": "iam:*",
  "Resource": "*",
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```

**Time-based access:**
```json
{
  "Effect": "Allow",
  "Action": "ec2:*",
  "Resource": "*",
  "Condition": {
    "DateGreaterThan": {
      "aws:CurrentTime": "2024-06-01T00:00:00Z"
    },
    "DateLessThan": {
      "aws:CurrentTime": "2024-12-31T23:59:59Z"
    }
  }
}
```

**Resource tags:**
```json
{
  "Effect": "Allow",
  "Action": "ec2:TerminateInstances",
  "Resource": "arn:aws:ec2:*:*:instance/*",
  "Condition": {
    "StringEquals": {
      "ec2:ResourceTag/Environment": "dev"
    }
  }
}
```

---

## Q8: How do you handle cross-account access securely?

**Answer:**
Cross-account access allows users/roles from one AWS account to access resources in another.

**Security best practices:**

**1. Always use external ID:**
```json
{
  "Effect": "Allow",
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT-B:root"
  },
  "Action": "sts:AssumeRole",
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "unique-random-string"
    }
  }
}
```

**Why external ID?** Prevents confused deputy problem where a third party tricks you into granting access.

**2. Use minimal permissions:**
```json
{
  "Effect": "Allow",
  "Action": [
    "s3:GetObject"
  ],
  "Resource": "arn:aws:s3:::bucket/*"
}
```

**3. Limit to specific role:**
```json
{
  "Principal": {
    "AWS": "arn:aws:iam::ACCOUNT-B:role/specific-role"
  }
}
```

**4. Time-limited sessions:**
```hcl
# Set maximum session duration
resource "aws_iam_role" "cross_account" {
  name               = "cross-account-role"
  max_session_duration = 3600  # 1 hour max
}
```

**5. Assume role with MFA (optional but recommended):**
```json
{
  "Condition": {
    "Bool": {
      "aws:MultiFactorAuthPresent": "true"
    }
  }
}
```

**Terraform example:**
```hcl
resource "aws_iam_role" "cross_account" {
  name = "cross-account-role"
  max_session_duration = 3600
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        AWS = "arn:aws:iam::TRUSTED-ACCOUNT:root"
      }
      Action = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "sts:ExternalId" = "unique-id"
        }
      }
    }]
  })
}
```

---

## Q9: How do you secure the root account?

**Answer:**
Root account has complete access to AWS. It must be protected carefully.

**Root account security checklist:**

**✓ Do:**
- [ ] Enable MFA (hardware or virtual)
- [ ] Rotate access keys every 90 days
- [ ] Delete all access keys if not used
- [ ] Use long, complex root password
- [ ] Enable CloudTrail logging
- [ ] Store credentials in secure location
- [ ] Share access only with security team
- [ ] Monitor root account usage

**✗ Don't:**
- [ ] Create access keys for root
- [ ] Use root for daily work
- [ ] Share root credentials
- [ ] Use predictable password
- [ ] Disable MFA
- [ ] Check root access keys into code

**Securing root in Terraform:**
```hcl
# Monitor root account usage
resource "aws_cloudtrail" "root_monitoring" {
  name                          = "root-monitoring"
  s3_bucket_name                = aws_s3_bucket.cloudtrail.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true
  
  depends_on = [aws_s3_bucket_policy.cloudtrail]
}

# Alert on root account activity
resource "aws_cloudwatch_log_group" "root_events" {
  name = "/aws/cloudtrail/root-events"
}

resource "aws_cloudwatch_event_rule" "root_activity" {
  name        = "root-activity"
  description = "Alert on root account activity"
  
  event_pattern = jsonencode({
    detail-type = ["AWS API Call via CloudTrail"]
    detail = {
      userIdentity = {
        type = ["Root"]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "root_alert" {
  rule      = aws_cloudwatch_event_rule.root_activity.name
  target_id = "RootAlert"
  arn       = aws_sns_topic.alerts.arn
}
```

---

## Q10: IAM Security Best Practices Checklist

**✓ Do:**
- [ ] Use least privilege principle
- [ ] Create roles for applications (not users)
- [ ] Use trust policies to control who assumes role
- [ ] Use permission boundaries for delegation
- [ ] Implement RBAC based on job function
- [ ] Use conditions (IP, MFA, time, tags)
- [ ] Enable CloudTrail logging
- [ ] Rotate credentials every 90 days
- [ ] Use external ID for cross-account access
- [ ] Use resource-based policies
- [ ] Implement explicit deny for guardrails
- [ ] Require MFA for sensitive operations
- [ ] Regular IAM policy reviews (quarterly)
- [ ] Use temporary credentials (STS, not keys)
- [ ] Monitor root account activity

**✗ Don't:**
- [ ] Use wildcard actions (*) or resources (*)
- [ ] Create access keys for root account
- [ ] Hardcode AWS credentials in code
- [ ] Use shared AWS accounts
- [ ] Create IAM users for applications
- [ ] Grant admin access without approval
- [ ] Skip external ID for cross-account
- [ ] Use long-term credentials unnecessarily
- [ ] Ignore IAM policy violations
- [ ] Share AWS credentials
- [ ] Use root account for daily work
- [ ] Forget to set permission boundaries
- [ ] Create policies without review
- [ ] Use overly broad resources in policies
- [ ] Disable CloudTrail logging

---

## Quick Reference Commands

```bash
# List IAM users
aws iam list-users

# List IAM roles
aws iam list-roles

# Get role policy
aws iam get-role-policy --role-name my-role --policy-name my-policy

# Get role trust policy
aws iam get-role --role-name my-role

# Simulate policy (check if action allowed)
aws iam simulate-principal-policy \
  --policy-source-arn arn:aws:iam::123456789:role/my-role \
  --action-names s3:GetObject \
  --resource-arns arn:aws:s3:::bucket/*

# Assume role
aws sts assume-role \
  --role-arn arn:aws:iam::123456789:role/my-role \
  --role-session-name my-session

# Assume role with MFA
aws sts assume-role \
  --role-arn arn:aws:iam::123456789:role/my-role \
  --role-session-name my-session \
  --serial-number arn:aws:iam::123456789:mfa/user \
  --token-code 123456

# List access keys
aws iam list-access-keys --user-name john

# Create access key
aws iam create-access-key --user-name john

# Delete access key
aws iam delete-access-key --user-name john --access-key-id AKIAIOSFODNN7EXAMPLE

# Get current identity
aws sts get-caller-identity
```

---

## Further Learning

- AWS IAM Documentation: https://docs.aws.amazon.com/iam/
- IAM Best Practices: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html
- Policy Simulator: https://policysim.aws.amazon.com/
- IAM Policy Examples: https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies_examples.html

