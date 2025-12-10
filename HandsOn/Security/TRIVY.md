# Trivy IaC Scanning Interview Guide

## Q1: What is Trivy and how is it different from tfsec?

**Answer:**
Trivy is a comprehensive security scanner that checks for vulnerabilities, misconfigurations, secrets, and license violations across multiple artifact types.

**Trivy vs tfsec:**

| Aspect | Trivy | tfsec |
|--------|-------|-------|
| **Purpose** | Multi-artifact scanner | Terraform-focused security |
| **Scan Types** | Filesystem, images, repos, SBOM | Terraform files only |
| **Coverage** | Vulnerabilities + misconfigurations + secrets + licenses | Security misconfigurations |
| **Database** | CVE database + custom rules | Custom Terraform rules |
| **Speed** | Medium (database dependent) | Very fast |
| **Setup** | Simple | Very simple |
| **Use Cases** | Container + IaC scanning | Terraform-only projects |
| **Output** | JSON, SARIF, table, cyclonedx | JSON, SARIF, table |
| **Multi-cloud** | Better (all providers) | Good (all providers) |

**When to use Trivy:**
- ✓ Scanning Docker images
- ✓ Finding CVEs in dependencies
- ✓ License compliance checking
- ✓ Multi-artifact pipeline
- ✓ Container registry scanning
- ✓ Full compliance scanning

**When to use tfsec:**
- ✓ Terraform-only projects
- ✓ Fast CI/CD feedback
- ✓ Pre-commit hooks (lightweight)
- ✓ Minimal infrastructure

---

## Q2: What types of scans can Trivy perform?

**Answer:**
Trivy supports multiple scan types for comprehensive coverage.

**Scan Types:**

| Scan Type | Command | Purpose |
|-----------|---------|---------|
| **Filesystem** | `trivy fs .` | Scan Terraform, Dockerfile, config files |
| **Docker Image** | `trivy image myimage:latest` | Scan container image for vulnerabilities |
| **Repository** | `trivy repo https://github.com/user/repo` | Scan GitHub/GitLab repo |
| **SBOM** | `trivy sbom report.cyclonedx` | Analyze Software Bill of Materials |
| **Config** | `trivy config .` | Scan configuration files specifically |
| **Archive** | `trivy image archive.tar` | Scan tar/zip archives |

**Filesystem scan (most common for Terraform):**
```bash
# Scan all Terraform files in directory
trivy fs .

# Scan specific directory
trivy fs ./terraform

# Show only HIGH and CRITICAL
trivy fs . --severity HIGH,CRITICAL

# Include license checks
trivy fs . --license-full

# JSON output
trivy fs . -f json -o results.json
```

**Docker image scan:**
```bash
# Scan local image
trivy image myimage:latest

# Scan image from registry
trivy image gcr.io/project/image:tag

# Skip OS vulnerabilities (focus on app deps)
trivy image --severity HIGH myimage:latest
```

**Config scan (dedicated IaC scanning):**
```bash
# Scan configuration files
trivy config .

# Scan specific format
trivy config . --format json
```

---

## Q3: How do you install and run Trivy?

**Answer:**

**Installation (macOS):**
```bash
brew install trivy
```

**Installation (Linux - Ubuntu/Debian):**
```bash
# Add repository
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

# Install
sudo apt-get update
sudo apt-get install trivy
```

**Installation (Windows):**
```bash
# Using Chocolatey
choco install trivy

# Or download from: https://github.com/aquasecurity/trivy/releases
```

**Basic usage:**
```bash
# Scan current directory
trivy fs .

# Scan with severity filter
trivy fs . --severity HIGH,CRITICAL

# Show detailed output
trivy fs . -v

# JSON output
trivy fs . -f json > results.json

# SARIF output (GitHub)
trivy fs . -f sarif > results.sarif

# Exit with non-zero on findings
trivy fs . --exit-code 1

# Skip update (offline scan)
trivy fs . --skip-update
```

---

## Q4: What vulnerabilities and misconfigurations does Trivy detect?

**Answer:**

**Vulnerability types Trivy detects:**

1. **CVE (Common Vulnerabilities and Exposures)**
   - Dependencies with known security issues
   - Outdated software versions
   - Examples: Log4j, OpenSSL, Apache

2. **Misconfigurations**
   - Unencrypted databases
   - Overly permissive security groups
   - Hardcoded secrets
   - Public buckets

3. **Secrets**
   - AWS access keys
   - Private SSH keys
   - API tokens
   - Database passwords

4. **License violations**
   - GPL usage (when restricted)
   - Proprietary licenses
   - AGPL in closed source

**Common misconfigurations detected:**

| Category | Examples |
|----------|----------|
| **AWS** | Unencrypted S3, public RDS, open security groups |
| **Kubernetes** | Root containers, privileged pods, no network policies |
| **Docker** | Running as root, latest tags, hardcoded secrets |
| **IAM** | Wildcard permissions, MFA disabled, hardcoded credentials |
| **Encryption** | Unencrypted storage, disabled logging, no TLS |

**Severity levels:**

| Level | Action |
|-------|--------|
| **CRITICAL** | Immediate fix required |
| **HIGH** | Fix before production |
| **MEDIUM** | Plan to remediate |
| **LOW** | Low priority |

---

## Q5: How do you configure Trivy with trivy.yaml?

**Answer:**

**Configuration file location:** `trivy.yaml` (in project root)

**Example configuration:**
```yaml
# Severity filtering
severity:
  - HIGH
  - CRITICAL

# Directories to skip
skip-dirs:
  - .terraform
  - .git
  - node_modules
  - vendor
  - test

# Files to skip
skip-files:
  - "*.bak"
  - "old_*.tf"
  - ".terraform/**"

# Exit code behavior
exit-code: 1  # Non-zero if vulnerabilities found

# Output format
format: sarif
output: trivy-results.sarif

# Severity to exit code
severity-exit-code:
  CRITICAL: 1
  HIGH: 0     # Don't exit on HIGH
  MEDIUM: 0

# License scanning
license:
  # Severity of license checks
  severity:
    - HIGH

# Compliance reports
compliance:
  # Set compliance spec (aws, k8s, docker, etc)
  spec: aws

# Database settings
db:
  # Custom DB repository
  repository: ghcr.io/aquasecurity/trivy-db
  
  # Use offline DB
  skip-update: false

# Timeout settings
timeout: 10m

# Show vulnerabilities without fixes
show-suppressed: false

# List all packages (even without vulnerabilities)
list-all-pkgs: false

# Slow mode (more accurate)
slow: false
```

**Using configuration:**
```bash
# Automatically reads trivy.yaml in current directory
trivy fs .

# Or specify config explicitly
trivy fs . -c trivy.yaml
```

---

## Q6: How do you suppress false positives in Trivy?

**Answer:**

**Method 1: Inline comments in code**
```hcl
# For Terraform files, use comments to document exceptions
resource "aws_s3_bucket" "legacy_bucket" {
  bucket = "legacy-system-bucket"
  # trivy:skip=AVD-AWS-0086: Legacy bucket predating encryption requirement
}
```

**Method 2: .trivyignore file**
```
# File: .trivyignore

# Suppress specific vulnerability IDs
AVD-AWS-0086
GHSA-xxxx-yyyy-zzzz

# Suppress for specific resource
AVD-AWS-0001 exp:2025-01-01 "Migration planned Q1 2025"

# Multiple suppressions
AVD-AWS-0086
AVD-AWS-0089 exp:2024-06-01
```

**Method 3: Configuration file**
```yaml
# trivy.yaml

# Global skip list
skip-checks:
  - AVD-AWS-0086  # Known false positive in legacy system
  - GHSA-xxxx-yyyy-zzzz

# Severity to skip
skip-severity: LOW

# File/path specific rules
exclusions:
  - "test/**/*.tf"  # Skip test files
  - "**/legacy/**"  # Skip legacy directory
```

**Method 4: Environment variable**
```bash
# Skip specific checks
TRIVY_SKIP_CHECKS=AVD-AWS-0086 trivy fs .
```

**Method 5: Command line**
```bash
# Skip checks
trivy fs . --skip-checks AVD-AWS-0086

# Skip multiple checks
trivy fs . --skip-checks AVD-AWS-0086,AVD-AWS-0089

# Skip specific directories
trivy fs . --skip-dirs .terraform,test
```

**Best practices for suppression:**
- Document every suppression with reason
- Set expiration dates
- Review in code reviews
- Re-evaluate regularly
- Use lowest scope possible

---

## Q7: How do you integrate Trivy into GitHub Actions?

**Answer:**

**GitHub Actions workflow:**
```yaml
# File: .github/workflows/trivy.yml

name: Trivy Security Scan

on:
  pull_request:
  push:
    branches:
      - main

jobs:
  trivy-fs:
    name: Trivy Filesystem Scan
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      # Run Trivy filesystem scan
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-fs-results.sarif'
          severity: 'HIGH,CRITICAL'
      
      # Upload to GitHub Security
      - uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-fs-results.sarif'
          category: 'trivy-fs'

  trivy-config:
    name: Trivy Config Scan
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      # Scan configuration files
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config'
          scan-ref: '.'
          format: 'sarif'
          output: 'trivy-config-results.sarif'
      
      - uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-config-results.sarif'
          category: 'trivy-config'

  trivy-image:
    name: Trivy Container Image Scan
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      - uses: docker/setup-buildx-action@v2
      
      # Build image
      - uses: docker/build-push-action@v4
        with:
          context: .
          push: false
          load: true
          tags: myapp:latest
      
      # Scan image
      - uses: aquasecurity/trivy-action@master
        with:
          input: 'myapp:latest'
          format: 'sarif'
          output: 'trivy-image-results.sarif'
      
      - uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-image-results.sarif'
          category: 'trivy-image'
```

**Results in GitHub:**
- Pull request checks show scan status
- "Security" tab displays detailed findings
- SARIF upload creates code scanning alerts
- Can block merge if configured

---

## Q8: How do you perform compliance scanning with Trivy?

**Answer:**

Trivy generates compliance reports against security standards.

**Supported compliance frameworks:**

| Framework | Command | Use Case |
|-----------|---------|----------|
| **AWS** | `trivy fs . --compliance aws` | AWS CIS Benchmark |
| **Kubernetes** | `trivy image . --compliance k8s` | Kubernetes CIS |
| **Docker** | `trivy image . --compliance docker` | Docker CIS |
| **NIST** | `trivy image . --compliance nist` | NIST compliance |
| **PCI DSS** | `trivy image . --compliance pci-dss` | Payment Card Industry |

**Running compliance scan:**
```bash
# AWS compliance report
trivy fs . --compliance aws -f json -o compliance.json

# Generate HTML report
trivy fs . --compliance aws --format json | \
  jq -r '.Results[] | select(.Type=="AWS") | .Misconfigurations[]'

# Export as CSV for stakeholders
trivy fs . --compliance aws -f sarif -o compliance.sarif
```

**Compliance report structure:**
```json
{
  "Results": [
    {
      "Type": "AWS",
      "Misconfigurations": [
        {
          "Type": "Kubernetes",
          "ID": "AVD-AWS-0086",
          "Title": "S3 bucket without encryption",
          "Description": "S3 buckets should have encryption enabled",
          "Status": "FAILED",
          "Severity": "HIGH"
        }
      ]
    }
  ]
}
```

**Creating compliance report for audit:**
```bash
# Generate JSON report
trivy fs . --compliance aws -f json -o aws-compliance-report.json

# Generate summary
trivy fs . --compliance aws --exit-code 0 | tee compliance-summary.txt

# Track over time
trivy fs . --compliance aws -f json -o compliance-$(date +%Y%m%d).json
```

---

## Q9: How do you handle Trivy database updates in airgapped environments?

**Answer:**

In airgapped (offline) environments without internet access, use pre-downloaded databases.

**Downloading database for offline use:**

```bash
# On online machine with internet
trivy image --download-db-only

# Database saved to: ~/.cache/trivy/db/trivy.db

# Copy database to airgapped environment
# scp ~/.cache/trivy/db/trivy.db user@offline-host:/cache/trivy/

# Or create tar archive
tar -czf trivy-db.tar.gz -C ~/.cache/trivy db/
```

**Using offline database:**

```bash
# Set database directory
export TRIVY_TEMP_DIR=/cache/trivy

# Scan with skip-update
trivy fs . --skip-update --offline-scan

# Or disable DB download
trivy fs . --db-repository=""
```

**Offline configuration (trivy.yaml):**
```yaml
# Offline database location
db:
  repository: ""  # Disable remote DB
  skip-update: true

# Force offline mode
offline-scan: true

# Custom local database path
cache-dir: /cache/trivy
```

**Creating offline scanning container:**
```dockerfile
FROM aquasec/trivy:latest

# Copy database
COPY trivy.db /root/.cache/trivy/db/

# Run offline scan
CMD ["fs", "--skip-update", "."]
```

---

## Q10: Trivy vs Checkov vs tfsec - When to use each?

**Comparison:**

| Feature | Trivy | Checkov | tfsec |
|---------|-------|---------|-------|
| **Scan Types** | FS, image, repo, sbom | FS, framework configs | Terraform only |
| **Artifact Types** | All (Docker, K8s, Terraform) | All configs | Terraform only |
| **CVE Database** | Yes (Grype) | Limited | No |
| **Setup** | Very simple | Requires Python | Very simple |
| **Speed** | Medium | Medium | Very fast |
| **Rules Count** | 1000+ | 1000+ | 500+ |
| **License Checks** | Yes | Limited | No |
| **Performance** | Good | Good | Excellent |
| **Learning Curve** | Low | Medium | Low |

**When to use each:**

| Tool | Best For |
|------|----------|
| **Trivy** | Container scanning + IaC scanning combined, CVE detection needed |
| **Checkov** | Multi-framework IaC, policy enforcement, custom rules needed |
| **tfsec** | Terraform-only, lightweight, fast CI/CD |

**Recommended stack:**
```bash
# 1. Validate syntax (fastest)
terraform validate

# 2. Quick security check (fast)
tfsec . --minimum-severity HIGH

# 3. CVE scanning (medium)
trivy fs . --severity HIGH,CRITICAL

# 4. Policy enforcement (slowest, most thorough)
checkov -d . --framework terraform
```

---

## Q11: Trivy Best Practices Checklist

**✓ Do:**
- [ ] Run on every commit (pre-commit hook)
- [ ] Integrate into CI/CD pipeline
- [ ] Scan container images before push
- [ ] Update database regularly
- [ ] Document all suppressions
- [ ] Review suppressions in PRs
- [ ] Use configuration file (trivy.yaml)
- [ ] Include .trivyignore in repo
- [ ] Monitor for new vulnerabilities
- [ ] Set appropriate severity thresholds
- [ ] Use SARIF for GitHub integration
- [ ] Scan multiple artifact types
- [ ] Track compliance over time

**✗ Don't:**
- [ ] Skip database updates
- [ ] Suppress without documentation
- [ ] Use in offline mode with stale DB
- [ ] Ignore HIGH/CRITICAL findings
- [ ] Disable exit codes in CI
- [ ] Use default settings everywhere
- [ ] Forget to scan images
- [ ] Skip license checks
- [ ] Run without severity filtering
- [ ] Combine with single tool only

---

## Quick Reference Commands

```bash
# Basic filesystem scan
trivy fs .

# Severity filter
trivy fs . --severity HIGH,CRITICAL

# Show all vulnerabilities
trivy fs . --list-all-pkgs

# JSON output
trivy fs . -f json -o results.json

# SARIF output (GitHub)
trivy fs . -f sarif -o results.sarif

# Scan Docker image
trivy image myimage:latest

# Config scan
trivy config .

# Compliance scan
trivy fs . --compliance aws

# Skip updates (offline)
trivy fs . --skip-update

# Skip directories
trivy fs . --skip-dirs .terraform,test

# Exit on findings
trivy fs . --exit-code 1

# Verbose output
trivy fs . -v

# Update database
trivy image --download-db-only

# Version check
trivy version

# Check for newer trivy version
trivy image --version
```

---

## Further Learning

- Official Documentation: https://aquasecurity.github.io/trivy/
- GitHub Repository: https://github.com/aquasecurity/trivy
- Supported Checks: https://aquasecurity.github.io/trivy/latest/docs/
- Compliance Specs: https://aquasecurity.github.io/trivy/latest/docs/compliance/

