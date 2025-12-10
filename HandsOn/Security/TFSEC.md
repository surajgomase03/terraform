# tfsec Scanning Interview Guide

## Q1: What is tfsec and why is it important?

**Answer:**
tfsec is a static analysis security scanner for Terraform code that identifies potential security vulnerabilities, compliance issues, and misconfigurations before deployment.

**Why it's important:**
- **Shift-Left Security:** Find issues early (development, not production)
- **Automated Scanning:** No manual review needed
- **CI/CD Integration:** Built into pipeline
- **Compliance:** Detect policy violations (CIS, HIPAA, PCI-DSS)
- **Cost:** Prevent security incidents (expensive to remediate post-production)
- **Consistency:** Same rules for all developers

**Common findings:**
- Unencrypted databases, S3 buckets
- Overly permissive security groups
- Hardcoded secrets
- Missing VPC flow logs
- Unrestricted IAM permissions
- Unencrypted EBS volumes
- Public RDS databases

---

## Q2: How do you install and run tfsec?

**Answer:**

**Installation (macOS/Linux):**
```bash
# Homebrew
brew install tfsec

# Or download from GitHub
curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | bash
```

**Installation (Windows):**
```bash
# Chocolatey
choco install tfsec

# Or download from GitHub releases
# https://github.com/aquasecurity/tfsec/releases
```

**Basic scan:**
```bash
# Scan current directory
tfsec .

# Scan specific directory
tfsec ./terraform

# Scan with verbosity
tfsec . -v
```

**Output formats:**
```bash
# JSON (for processing)
tfsec . -f json > results.json

# SARIF (for GitHub Code Scanning)
tfsec . -f sarif > results.sarif

# CSV (for reports)
tfsec . -f csv > results.csv

# JUnit (for CI/CD integration)
tfsec . -f junit > results.xml

# Tabular (human-readable, default)
tfsec .
```

---

## Q3: What are tfsec severity levels?

**Answer:**

tfsec classifies findings by severity:

| Severity | Impact | Action |
|----------|--------|--------|
| **CRITICAL** | Severe security risk | Must fix before deployment |
| **HIGH** | Significant vulnerability | Should fix before deployment |
| **MEDIUM** | Notable weakness | Fix in planned release |
| **LOW** | Minor issue | Document and track |
| **WARNING** | Informational | Review and monitor |

**Filtering by severity:**
```bash
# Only HIGH and above
tfsec . --minimum-severity HIGH

# Only CRITICAL
tfsec . --minimum-severity CRITICAL

# Include all levels
tfsec . --minimum-severity WARNING
```

**Example severities:**
- **CRITICAL:** Hardcoded secrets, wildcard IAM permissions
- **HIGH:** Unencrypted databases, public S3 buckets, unrestricted security groups
- **MEDIUM:** Missing versioning, no VPC flow logs, disabled logging
- **LOW:** Missing tags, documentation issues

---

## Q4: How do you skip or ignore tfsec checks?

**Answer:**

**Skip check inline (in Terraform code):**
```hcl
# Option 1: Skip specific check
resource "aws_s3_bucket" "my_bucket" {
  bucket = "my-bucket"
  #tfsec:skip=aws-s3-enable-bucket-encryption:false Exempt due to XYZ
}

# Option 2: Skip with reason
resource "aws_security_group" "example" {
  name = "example"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # tfsec:skip=aws-vpc-add-ingress-rule:Legacy system requirement
  }
}

# Option 3: Skip entire file
# tfsec:skip=all

# Option 4: Skip multiple checks
# tfsec:skip=aws-s3-enable-bucket-encryption,aws-s3-block-public-access
```

**Skip via CLI:**
```bash
# Skip single check
tfsec . --skip aws-s3-enable-bucket-encryption

# Skip multiple checks
tfsec . --skip aws-s3-enable-bucket-encryption,aws-s3-block-public-access
```

**Skip via configuration file (.tfsec/config.yml):**
```yaml
# Global exceptions
skip_checks:
  - AVD-AWS-0001  # Check ID
  - aws-s3-enable-bucket-encryption  # Check name
  
# Minimum severity to report
minimum_severity: MEDIUM

# Rules to enforce
rules:
  - aws-s3-block-public-access
  - aws-rds-encrypt-instance-storage
  - aws-vpc-add-ingress-rule
```

**Best practice:**
- Document every exception with reason
- Prefer inline comments for context
- Review exemptions in code reviews
- Re-evaluate regularly
- Use lowest possible skip scope

---

## Q5: How do you integrate tfsec into CI/CD?

**Answer:**

**GitHub Actions (most common):**
```yaml
# File: .github/workflows/tfsec.yml

name: tfsec scan
on:
  pull_request:
  push:
    branches:
      - main

jobs:
  tfsec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Run tfsec scan
      - uses: aquasecurity/tfsec-action@latest
        with:
          working_directory: '.'
          version: latest
          format: 'sarif'
          output_file: results.sarif
      
      # Upload results to GitHub Security tab
      - uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: results.sarif
```

**GitLab CI:**
```yaml
tfsec:
  image: aquasec/tfsec:latest
  stage: scan
  script:
    - tfsec . -f json > results.json
  artifacts:
    reports:
      sast: results.json
  allow_failure: true  # Don't fail pipeline on findings
```

**Jenkins:**
```groovy
stage('tfsec') {
    steps {
        sh 'tfsec . -f junit > results.xml'
        junit 'results.xml'
    }
}
```

**Blocking pipeline on critical issues:**
```bash
# Fail if any CRITICAL findings
tfsec . --minimum-severity CRITICAL --exit-code 1

# Fail if any HIGH or above
tfsec . --minimum-severity HIGH --exit-code 1

# Allow LOW/WARNING, but track
tfsec . --minimum-severity MEDIUM --exit-code 1
```

---

## Q6: How do you configure tfsec with .tfsec/config.yml?

**Answer:**

**Configuration file location:** `.tfsec/config.yml`

**Example configuration:**
```yaml
# Minimum severity to report
minimum_severity: MEDIUM

# Rules to enforce (if empty, all enabled)
rules:
  - aws-s3-enable-bucket-encryption
  - aws-s3-block-public-access
  - aws-rds-encrypt-instance-storage
  - aws-vpc-add-ingress-rule
  - aws-iam-no-wildcard-actions

# Skip specific checks globally
skip_checks:
  - AVD-AWS-0001
  - aws-s3-enable-versioning  # Not required for this project

# Custom checks (advanced)
custom_checks:
  - name: No hardcoded AWS accounts
    description: Detect hardcoded AWS account IDs
    impact: MEDIUM
    resolution: Use data sources instead
    code: 'resource.aws_iam_policy.*.policy has "123456789012"'

# Only scan specific resource types
resource_types:
  - aws_s3_bucket
  - aws_rds_cluster
  - aws_security_group

# Exclude directories
exclude_paths:
  - '**/.terraform/**'
  - 'test/**'
  - 'old_configs/**'

# Formatting options
format: sarif
output: results.sarif
```

**Using configuration:**
```bash
# Automatically use .tfsec/config.yml
tfsec .

# Or specify explicitly
tfsec . --config-file .tfsec/config.yml
```

---

## Q7: What are common tfsec checks and findings?

**Answer:**

**HIGH severity checks:**

| Check ID | Resource | Issue | Fix |
|----------|----------|-------|-----|
| **aws-s3-enable-bucket-encryption** | S3 Bucket | No encryption | Add `server_side_encryption_configuration` |
| **aws-s3-block-public-access** | S3 Bucket | Public access | Add `public_access_block` |
| **aws-rds-encrypt-instance-storage** | RDS | Unencrypted | Set `storage_encrypted = true` |
| **aws-rds-no-public-db** | RDS | Public access | Set `publicly_accessible = false` |
| **aws-vpc-add-ingress-rule** | Security Group | Open to internet | Restrict CIDR blocks |
| **aws-iam-no-wildcard-actions** | IAM Policy | Wildcard permissions | Use specific actions |
| **aws-ebs-encryption-by-default** | EBS Volume | Unencrypted | Set `encrypted = true` |
| **general-secrets-found** | All | Hardcoded secrets | Use random/external source |

**MEDIUM severity checks:**

| Check ID | Resource | Issue | Fix |
|----------|----------|-------|-----|
| **aws-s3-enable-versioning** | S3 Bucket | No versioning | Add `versioning` block |
| **aws-vpc-enable-flow-logs** | VPC | No flow logs | Add `flow_log` resource |
| **aws-cloudtrail-enable-logging** | CloudTrail | Not logging | Set `is_logging = true` |
| **aws-kms-enable-key-rotation** | KMS Key | No rotation | Set `enable_key_rotation = true` |
| **aws-rds-enable-backup** | RDS | No backup | Set `backup_retention_period > 0` |

---

## Q8: How do you handle false positives in tfsec?

**Answer:**

False positives occur when tfsec reports an issue that isn't actually a problem.

**Common false positives:**

1. **Legacy systems requiring open access**
   ```hcl
   # False positive: This old system actually needs public access
   resource "aws_security_group" "legacy" {
     ingress {
       from_port   = 22
       to_port     = 22
       protocol    = "tcp"
       cidr_blocks = ["0.0.0.0/0"]
       # tfsec:skip=aws-vpc-add-ingress-rule:Legacy system deprecating in Q3
     }
   }
   ```

2. **Development environments**
   ```hcl
   # False positive: Dev bucket doesn't need encryption
   resource "aws_s3_bucket" "dev" {
     bucket = "dev-bucket"
     # tfsec:skip=aws-s3-enable-bucket-encryption:Dev only, not production
   }
   ```

3. **Testing scenarios**
   ```hcl
   # False positive: Test needs temporary public access
   resource "aws_db_instance" "test" {
     publicly_accessible = true
     # tfsec:skip=aws-rds-no-public-db:Test database, temporary only
   }
   ```

**Handling false positives:**

1. **Document with comments:**
   ```hcl
   resource "aws_s3_bucket" "logs" {
     bucket = "access-logs"
     # tfsec:skip=aws-s3-enable-bucket-encryption:
     # Reason: This bucket stores CloudFront logs which don't need encryption
     # Reviewed: YYYY-MM-DD by Security Team
   }
   ```

2. **Update configuration file:**
   ```yaml
   skip_checks:
     - AVD-AWS-0105  # S3 versioning not needed for log bucket
   ```

3. **Update rules in config:**
   ```yaml
   rules:
     # Don't enforce certain rules for this project
     - aws-rds-encrypt-instance-storage  # Only, not optional
   ```

4. **Create custom rules:**
   ```yaml
   custom_checks:
     - name: Enforce encryption only for prod
       code: 'resource.aws_s3_bucket[contains(name, "prod")].server_side_encryption_configuration exists'
   ```

**Best practice:**
- Review every exception in PR/code review
- Document reason and expiration date
- Escalate non-obvious exemptions to security team
- Re-evaluate periodically

---

## Q9: How does tfsec compare to other security scanners?

**Answer:**

**Comparison with other tools:**

| Feature | tfsec | Trivy | checkov | terraform validate |
|---------|-------|-------|---------|-------------------|
| **Purpose** | IaC security | Multi-scan (container, IaC) | IaC compliance | Syntax validation |
| **Coverage** | Broad (AWS, Azure, GCP) | Comprehensive (CVE, IaC, config) | Extensive (policies) | Basic (syntax only) |
| **Setup** | Easy | Easy | Requires framework | Native |
| **Customization** | Good (config files) | Excellent (plugins) | Excellent (policies) | None |
| **Speed** | Very fast | Fast | Medium | Fast |
| **False positives** | Low | Medium | Low | None |
| **Learning curve** | Low | Low | Medium | None |
| **Best for** | Terraform-only | Multi-tool environments | Policy enforcement | Basic validation |

**When to use each:**

| Tool | When to Use |
|------|------------|
| **tfsec** | Pure Terraform projects, quick feedback, CI/CD |
| **Trivy** | Docker + Terraform + dependencies scanning |
| **checkov** | Policy-heavy organizations, multi-tool IaC |
| **terraform validate** | Syntax validation (always run first) |

**Recommended combination:**
```bash
# 1. Validate syntax
terraform validate

# 2. Format check
terraform fmt -check

# 3. Run tfsec
tfsec . --minimum-severity HIGH

# 4. (Optional) Run trivy for container images
trivy image myimage:latest

# 5. (Optional) Run checkov for policy enforcement
checkov -d .
```

---

## Q10: tfsec Best Practices Checklist

**✓ Do:**
- [ ] Run tfsec on every commit (pre-commit hook)
- [ ] Integrate into CI/CD pipeline
- [ ] Set minimum severity threshold
- [ ] Document all exemptions
- [ ] Review exemptions in PRs
- [ ] Update tfsec regularly (`brew upgrade tfsec`)
- [ ] Use .tfsec/config.yml for configuration
- [ ] Include GitHub Actions badge in README
- [ ] Monitor update frequency (weekly)
- [ ] Test custom rules before deployment
- [ ] Use SARIF output for GitHub integration

**✗ Don't:**
- [ ] Skip all checks without review
- [ ] Ignore CRITICAL findings
- [ ] Commit code with tfsec warnings
- [ ] Disable tfsec in production
- [ ] Use wildcard skips
- [ ] Ignore outdated rule definitions
- [ ] Skip security scans in CI/CD
- [ ] Use tfsec alone (combine with other tools)
- [ ] Forget to update exceptions
- [ ] Assume tfsec catches all issues

---

## Q11: How do you create a GitHub Action workflow with tfsec?

**Answer:**

**Complete GitHub Actions workflow:**
```yaml
# File: .github/workflows/security.yml

name: Security Scan

on:
  pull_request:
    paths:
      - 'terraform/**'
      - '.github/workflows/security.yml'
  push:
    branches:
      - main
    paths:
      - 'terraform/**'

jobs:
  tfsec:
    name: tfsec Scan
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0
      
      - name: Run tfsec scan
        uses: aquasecurity/tfsec-action@latest
        with:
          working_directory: 'terraform/'
          version: 'latest'
          format: 'sarif'
          output_file: 'tfsec-results.sarif'
          exit_code: 1  # Fail if findings
      
      - name: Upload results to GitHub Security
        if: always()  # Upload even if scan fails
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'tfsec-results.sarif'
          category: 'tfsec'
      
      - name: Publish scan summary
        if: always()
        run: |
          echo "## tfsec Results" >> $GITHUB_STEP_SUMMARY
          cat tfsec-results.sarif >> $GITHUB_STEP_SUMMARY

  terraform-validate:
    name: Terraform Validate
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform init
        run: terraform -chdir=terraform init -backend=false
      
      - name: Terraform validate
        run: terraform -chdir=terraform validate
      
      - name: Terraform fmt check
        run: terraform -chdir=terraform fmt -check -recursive
```

**Results in GitHub:**
- Pull request checks show scan results
- "Security" tab shows detailed findings
- Blocks merge if enabled in branch protection

---

## Quick Reference Commands

```bash
# Basic scan
tfsec .

# Scan with minimum severity
tfsec . --minimum-severity HIGH

# Output in JSON
tfsec . -f json > results.json

# Output in SARIF
tfsec . -f sarif > results.sarif

# Skip check
tfsec . --skip aws-s3-enable-bucket-encryption

# Skip multiple checks
tfsec . --skip check1,check2,check3

# List all checks
tfsec -l

# Show check details
tfsec -c aws-s3-enable-bucket-encryption

# Scan specific directory
tfsec ./terraform

# Show excluded files
tfsec . -v

# Run with config
tfsec . -c .tfsec/config.yml

# Force exit code
tfsec . --exit-code 1
```

---

## Further Learning

- Official tfsec Documentation: https://aquasecurity.github.io/tfsec/latest/
- GitHub Repository: https://github.com/aquasecurity/tfsec
- Check List: https://aquasecurity.github.io/tfsec/latest/checks/aws/
- Custom Checks: https://aquasecurity.github.io/tfsec/latest/custom-checks/

