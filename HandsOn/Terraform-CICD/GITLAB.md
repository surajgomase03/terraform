# GitLab Terraform CI/CD Guide

## Q1: How do you set up a GitLab CI/CD pipeline for Terraform?

**Answer:**
GitLab CI/CD uses `.gitlab-ci.yml` to define automated workflow.

**Basic `.gitlab-ci.yml` structure:**
```yaml
stages:
  - init
  - plan
  - approve
  - apply
  - destroy

variables:
  TF_ROOT: ${CI_PROJECT_DIR}/terraform
  TF_VERSION: "1.5.0"
  AWS_REGION: "us-east-1"
  TF_INPUT: "false"
  TF_IN_AUTOMATION: "true"

before_script:
  - cd ${TF_ROOT}

init:
  stage: init
  image: hashicorp/terraform:${TF_VERSION}
  script:
    - terraform init -backend-config=backend.hcl
  artifacts:
    paths:
      - terraform/.terraform
      - terraform/.terraform.lock.hcl

plan:
  stage: plan
  image: hashicorp/terraform:${TF_VERSION}
  script:
    - terraform plan -out=tfplan
    - terraform show -json tfplan > plan.json
  artifacts:
    paths:
      - terraform/tfplan
      - terraform/plan.json
    reports:
      dotenv: plan.env

approval:
  stage: approve
  image: alpine:latest
  script:
    - echo "Waiting for manual approval"
  when: manual

apply:
  stage: apply
  image: hashicorp/terraform:${TF_VERSION}
  script:
    - terraform apply -auto-approve tfplan
  when: on_success
  only:
    - main

destroy:
  stage: destroy
  image: hashicorp/terraform:${TF_VERSION}
  script:
    - terraform destroy -auto-approve
  when: manual
```

**Key GitLab features:**
- **Stages:** Sequential pipeline execution
- **Artifacts:** Share files between jobs
- **when:** Conditional job execution
- **environments:** Deploy environment tracking
- **Protected branches:** Restrict deployments
- **Manual jobs:** Approval gates
- **Schedules:** Drift detection jobs

---

## Q2: How do you handle AWS credentials in GitLab CI/CD?

**Answer:**
GitLab provides multiple secure methods for credential management.

**Option 1: GitLab CI/CD Variables**
```yaml
# Project → Settings → CI/CD → Variables

variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID  # Protected variable
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
  AWS_REGION: "us-east-1"

stages:
  - deploy

deploy:
  stage: deploy
  image: amazon/aws-cli:latest
  script:
    - aws sts get-caller-identity
    - terraform apply -auto-approve
```

**Option 2: IAM Role (Recommended)**
```yaml
# If GitLab Runner on EC2 with IAM role attached

deploy:
  stage: deploy
  image: hashicorp/terraform:latest
  script:
    # Uses EC2 instance IAM role automatically
    - terraform init
    - terraform apply -auto-approve
  environment:
    name: production
```

**Option 3: OIDC Token (Recommended modern approach)**
```yaml
# GitLab → AWS OIDC Federation

image: hashicorp/terraform:latest

variables:
  AWS_ROLE_ARN: $AWS_ROLE_ARN
  AWS_SESSION_NAME: "terraform-ci-${CI_COMMIT_SHA}"
  AWS_WEB_IDENTITY_TOKEN_FILE: /tmp/web_identity_token

before_script:
  - echo $CI_JOB_JWT_V2 > ${AWS_WEB_IDENTITY_TOKEN_FILE}

deploy:
  stage: deploy
  script:
    - aws sts get-caller-identity
    - terraform apply -auto-approve
```

**Option 4: Vault Integration**
```yaml
# Using Vault for secret management

variables:
  VAULT_ADDR: "https://vault.example.com"
  VAULT_NAMESPACE: "admin"

deploy:
  stage: deploy
  image: vault:latest
  before_script:
    - export VAULT_TOKEN=$(vault write -field=token auth/jwt/login role=gitlab-role jwt=$CI_JOB_JWT_V2)
    - export AWS_CREDS=$(vault kv get -format=json secret/aws)
    - export AWS_ACCESS_KEY_ID=$(echo $AWS_CREDS | jq -r '.data.data.access_key')
    - export AWS_SECRET_ACCESS_KEY=$(echo $AWS_CREDS | jq -r '.data.data.secret_key')
  script:
    - terraform apply -auto-approve
```

**Best practices:**
- ✓ Use masked variables (hide from logs)
- ✓ Use protected variables (CI/CD only)
- ✓ Use OIDC tokens (no long-lived credentials)
- ✓ Rotate credentials every 90 days
- ✓ Use temporary STS tokens
- ✓ Audit credential access in logs
- ✗ Don't commit credentials to Git
- ✗ Don't use root/admin credentials

---

## Q3: How do you configure the Terraform backend in GitLab?

**Answer:**
Backend configuration specifies where Terraform state is stored (S3 + DynamoDB).

**S3 backend configuration:**
```yaml
before_script:
  - cd terraform
  - cat > backend-config.hcl <<EOF
bucket         = "${TF_STATE_BUCKET}"
key            = "${CI_PROJECT_NAME}/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true
EOF
  - terraform init -backend-config=backend-config.hcl

stages:
  - init
  - plan
```

**Dynamic backend configuration per environment:**
```yaml
variables:
  TF_ROOT: "terraform"

.terraform_init: &terraform_init
  image: hashicorp/terraform:latest
  before_script:
    - cd ${TF_ROOT}
    - |
      terraform init \
        -backend-config="bucket=terraform-${CI_ENVIRONMENT_NAME}" \
        -backend-config="key=${CI_COMMIT_BRANCH}/terraform.tfstate" \
        -backend-config="region=us-east-1" \
        -backend-config="dynamodb_table=terraform-locks" \
        -reconfigure

init:dev:
  <<: *terraform_init
  environment:
    name: dev
  only:
    - develop

init:prod:
  <<: *terraform_init
  environment:
    name: prod
  only:
    - main
```

**Backend with state locking:**
```hcl
# backend-config.hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
    
    # State locking prevents concurrent modifications
    # DynamoDB table must have primary key: LockID (String)
  }
}
```

---

## Q4: How do you implement approval workflows in GitLab?

**Answer:**
GitLab provides multiple approval mechanisms for controlled deployments.

**Option 1: Manual jobs (click to run)**
```yaml
stages:
  - plan
  - approve
  - apply

plan:
  stage: plan
  script:
    - terraform plan -out=tfplan

approval:
  stage: approve
  script:
    - echo "Deployment ready"
  when: manual  # Requires manual trigger

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - plan
```

**Option 2: Protected environments**
```yaml
deploy:to:prod:
  stage: deploy
  environment:
    name: production
    url: https://prod.example.com
    deployment_tier: production
  script:
    - terraform apply -auto-approve
  only:
    - main
  # Environment requires approval in GitLab UI:
  # Project → Deployments → Environments → Configure protection rules
```

**Option 3: Merge request pipeline approval**
```yaml
stages:
  - plan
  - approve
  - apply

plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - tfplan
  only:
    - merge_requests

approval:
  stage: approve
  needs:
    - plan
  script:
    - echo "Merge request approved for deployment"
  when: manual
  only:
    - merge_requests

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  only:
    - main  # Only runs on main branch after merge
```

**Option 4: Approval rules (Enterprise)**
```yaml
# Set approval rule via API:
# POST /projects/:id/approval_rules

deploy:prod:
  stage: deploy
  environment:
    name: production
    deployment_tier: production
  script:
    - terraform apply -auto-approve
  only:
    - main
  
  # Requires approval via:
  # Project → Settings → General → Merge request approvals
  # - Minimum 2 approvers
  # - Approver group: terraform-admins
  # - Rule name: terraform-prod-deployment
```

**Option 5: Custom approval script**
```yaml
plan:
  stage: plan
  script:
    - terraform plan -json > plan.json
  artifacts:
    paths:
      - plan.json
    reports:
      dotenv: plan.env

approval:
  stage: approve
  script:
    - |
      # Extract resource count from plan
      RESOURCES=$(jq '.resource_changes | length' plan.json)
      echo "Planning to change $RESOURCES resources"
      
      # Require manual approval for large changes
      if [ $RESOURCES -gt 10 ]; then
        echo "⚠️ Large change detected - manual approval required"
        exit 0  # Job pauses here for manual continuation
      fi
  when: manual

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  dependencies:
    - plan
```

---

## Q5: How do you set up GitLab Runner for Terraform?

**Answer:**
GitLab Runner executes pipeline jobs. Register and configure for Terraform.

**Install GitLab Runner:**
```bash
# Install on Ubuntu
curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh | bash
apt-get install gitlab-runner

# Or use Docker
docker run -d --name gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  gitlab/gitlab-runner:latest
```

**Register runner:**
```bash
# Interactive registration
gitlab-runner register \
  --url https://gitlab.example.com \
  --registration-token RUNNER_TOKEN \
  --executor docker \
  --docker-image hashicorp/terraform:latest \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --tag-list terraform,aws \
  --description "Terraform runner" \
  --maintenance-note "CI/CD runner for Terraform"

# Or via config file
cat > /etc/gitlab-runner/config.toml <<EOF
[[runners]]
  name = "terraform-runner"
  url = "https://gitlab.example.com"
  token = "RUNNER_TOKEN"
  executor = "docker"
  [runners.docker]
    image = "hashicorp/terraform:latest"
    volumes = ["/var/run/docker.sock:/var/run/docker.sock"]
EOF
```

**Runner configuration:**
```toml
# /etc/gitlab-runner/config.toml

[[runners]]
  name = "terraform-prod-runner"
  url = "https://gitlab.example.com/"
  token = "xxxxx"
  executor = "docker"
  
  [runners.docker]
    image = "hashicorp/terraform:latest"
    privileged = true
    volumes = [
      "/var/run/docker.sock:/var/run/docker.sock",
      "/cache"
    ]
    memory = "2g"
    cpus = "2"
  
  [runners.machine]
    IdleCount = 0
    IdleTime = 600
    MaxBuilds = 100
```

**Custom runner with tools:**
```dockerfile
# Dockerfile.runner
FROM hashicorp/terraform:latest

RUN apk add --no-cache \
    aws-cli \
    git \
    jq \
    curl \
    python3 \
    py3-pip

# Install Checkov (policy as code)
RUN pip3 install checkov

# Install tfsec (security scanning)
RUN wget https://github.com/aquasecurity/tfsec/releases/download/v1.25.0/tfsec-linux-amd64 \
    && chmod +x tfsec-linux-amd64 \
    && mv tfsec-linux-amd64 /usr/local/bin/tfsec

ENTRYPOINT ["/bin/sh"]
```

---

## Q6: How do you handle environment-specific configurations?

**Answer:**
Different environments need different infrastructure and configurations.

**Using environment variables:**
```yaml
stages:
  - plan
  - apply

.deploy: &deploy_template
  stage: apply
  image: hashicorp/terraform:latest
  script:
    - terraform init -backend-config=backend.hcl
    - terraform apply -auto-approve \
        -var-file="environments/${ENVIRONMENT}.tfvars"

deploy:dev:
  <<: *deploy_template
  variables:
    ENVIRONMENT: dev
  environment:
    name: development
  only:
    - develop

deploy:staging:
  <<: *deploy_template
  variables:
    ENVIRONMENT: staging
  environment:
    name: staging
  only:
    - develop

deploy:prod:
  <<: *deploy_template
  variables:
    ENVIRONMENT: prod
  environment:
    name: production
  only:
    - main
```

**Environment-specific tfvars:**
```hcl
# environments/dev.tfvars
environment        = "dev"
instance_count     = 1
instance_type      = "t3.micro"
enable_monitoring  = false
backup_retention   = 7

# environments/prod.tfvars
environment        = "prod"
instance_count     = 3
instance_type      = "t3.medium"
enable_monitoring  = true
backup_retention   = 30
```

**Using GitLab environments:**
```yaml
deploy:prod:
  stage: deploy
  environment:
    name: production
    url: https://prod.example.com
    kubernetes:
      namespace: production
    deployment_tier: production
    auto_stop_in: 1 week
  variables:
    ENVIRONMENT: prod
  script:
    - terraform apply -auto-approve \
        -var-file="environments/${ENVIRONMENT}.tfvars"
  only:
    - main
```

---

## Q7: How do you prevent destruction of production resources?

**Answer:**
Protect production infrastructure from accidental deletion.

**Option 1: Branch protection + environment rules**
```yaml
destroy:
  stage: destroy
  image: hashicorp/terraform:latest
  script:
    - terraform destroy -auto-approve
  environment:
    name: development  # Only runs on development
  when: manual
  only:
    - develop
```

**Option 2: Terraform lifecycle rules**
```hcl
resource "aws_db_instance" "prod" {
  # Database configuration
  
  lifecycle {
    prevent_destroy = var.environment == "prod"
  }
}

resource "aws_s3_bucket" "prod" {
  # S3 bucket configuration
  
  lifecycle {
    prevent_destroy = true  # Always prevent destruction
  }
}
```

**Option 3: Protected environment + approvals**
```yaml
destroy:
  stage: destroy
  environment:
    name: production
    deployment_tier: production
    # This environment requires approval
    # Set in: Project → Deployments → Environments → Configure protection
  script:
    - terraform destroy -auto-approve
  when: manual
  only:
    - main

# Configure in GitLab UI:
# Project → Deployments → Environments → Configure
# - Required approvals: 2
# - Approvers: terraform-admins group
# - Access: Maintainers only
```

**Option 4: Explicit confirmation script**
```yaml
destroy:
  stage: destroy
  image: hashicorp/terraform:latest
  script:
    - |
      if [ "$CI_ENVIRONMENT_NAME" = "production" ]; then
        echo "⚠️ PRODUCTION DESTROY CONFIRMATION REQUIRED"
        echo "Environment: $CI_ENVIRONMENT_NAME"
        echo "Project: $CI_PROJECT_NAME"
        
        # Require manual trigger + approval
        if [ "$DESTROY_CONFIRMED" != "yes" ]; then
          echo "❌ Destroy cancelled - confirmation required"
          exit 1
        fi
      fi
      
      terraform destroy -auto-approve
  when: manual
  environment:
    name: development
  only:
    - develop
```

---

## Q8: How do you export Terraform outputs and share between jobs?

**Answer:**
Pipeline outputs needed by other jobs or deployed applications.

**Export outputs as artifacts:**
```yaml
plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
    - terraform show -json tfplan > plan.json
    - terraform show tfplan > plan.txt
  artifacts:
    paths:
      - terraform/tfplan
      - terraform/plan.json
      - terraform/plan.txt
    expire_in: 30 days

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
    - terraform output -json > outputs.json
    - terraform output -json instance_ids > instance_ids.json
  artifacts:
    paths:
      - terraform/outputs.json
      - terraform/instance_ids.json
    reports:
      dotenv: deploy.env

# Create deployment info
post_deploy:
  stage: deploy
  script:
    - |
      cat > deployment.txt <<EOF
Deployment Information
====================
Timestamp: $(date)
Commit: $CI_COMMIT_SHA
Branch: $CI_COMMIT_BRANCH
Environment: $CI_ENVIRONMENT_NAME

Resources:
$(terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value.value)"')
EOF
  artifacts:
    paths:
      - deployment.txt
  dependencies:
    - apply
```

**Share outputs via CI/CD variables:**
```yaml
export_outputs:
  stage: deploy
  script:
    - |
      VPC_ID=$(terraform output -raw vpc_id)
      INSTANCE_IDS=$(terraform output -json instance_ids | jq -c '.[]')
      
      # Export as dotenv artifacts
      echo "VPC_ID=$VPC_ID" >> vars.env
      echo "INSTANCE_IDS=$INSTANCE_IDS" >> vars.env
  artifacts:
    reports:
      dotenv: vars.env

# Use in downstream job
downstream_job:
  stage: test
  script:
    - echo "Using VPC: $VPC_ID"
    - echo "Instances: $INSTANCE_IDS"
  dependencies:
    - export_outputs
```

---

## Q9: How do you implement drift detection?

**Answer:**
Detect when infrastructure diverges from Terraform code.

**Scheduled drift detection pipeline:**
```yaml
stages:
  - plan

# Run hourly to detect drift
drift:detection:
  stage: plan
  image: hashicorp/terraform:latest
  script:
    - terraform init
    - terraform plan -json > drift-report.json
    - |
      # Check for changes
      CHANGES=$(jq '.resource_changes | length' drift-report.json)
      
      if [ "$CHANGES" -gt 0 ]; then
        echo "⚠️ Drift detected: $CHANGES resources"
        jq '.resource_changes[] | select(.change.actions[] | select(. != "no-op"))' drift-report.json
        
        # Notify team
        curl -X POST https://slack.com/api/chat.postMessage \
          -H 'Content-Type: application/json' \
          -d "{\"channel\": \"#infra-alerts\", \"text\": \"Terraform drift detected: $CHANGES changes\"}"
      else
        echo "✓ No drift detected"
      fi
  artifacts:
    paths:
      - drift-report.json
  schedule:
    cron: "0 * * * *"  # Every hour
```

**Scheduled job configuration:**
```yaml
# Go to: Project → CI/CD → Schedules
# Create new schedule:
# - Description: "Hourly drift detection"
# - Cron: 0 * * * *
# - Pipeline trigger: drift-detection-pipeline
# - Active: Yes
```

---

## Q10: GitLab Terraform Best Practices

**✓ Do:**
- [ ] Store state remotely (S3 + DynamoDB)
- [ ] Use protected branches for production
- [ ] Require approval for prod deployments
- [ ] Review plans before apply
- [ ] Use environment-specific tfvars
- [ ] Scan with tfsec/checkov
- [ ] Archive plan artifacts
- [ ] Implement drift detection
- [ ] Use OIDC tokens (no credentials)
- [ ] Set resource retention policy
- [ ] Implement rollback procedures
- [ ] Regular state backups

**✗ Don't:**
- [ ] Hardcode credentials in YAML
- [ ] Use local state
- [ ] Auto-approve production
- [ ] Skip plan review
- [ ] Commit tfstate to Git
- [ ] Use root credentials
- [ ] Run destroy without approval
- [ ] Share credentials between projects
- [ ] Ignore security scanning
- [ ] Apply without approval
- [ ] Delete tfstate files
- [ ] Mix environments in single pipeline

---

## Quick Reference Commands

```bash
# Create new pipeline schedule
curl --request POST \
  --url "https://gitlab.example.com/api/v4/projects/1/pipeline_schedules" \
  --header "PRIVATE-TOKEN: your-token" \
  --form "description=Drift Detection" \
  --form "cron=0 * * * *" \
  --form "ref=main" \
  --form "active=true"

# Trigger pipeline manually
curl --request POST \
  --url "https://gitlab.example.com/api/v4/projects/1/pipeline" \
  --header "PRIVATE-TOKEN: your-token" \
  --form "ref=main"

# View pipeline status
curl "https://gitlab.example.com/api/v4/projects/1/pipelines/123"

# Download artifact
curl --output artifact.zip \
  "https://gitlab.example.com/api/v4/projects/1/pipelines/123/artifacts"
```

---

## GitLab vs Jenkins Comparison

| Feature | GitLab | Jenkins |
|---------|--------|---------|
| **Configuration** | YAML (.gitlab-ci.yml) | Groovy (Jenkinsfile) |
| **Credentials** | CI/CD Variables + OIDC | Credentials Plugin + Vault |
| **Approvals** | Protected environments | Input/approval steps |
| **State Backend** | S3/GCS/Azure/TF Cloud | S3/GCS/Azure/TF Cloud |
| **Drift Detection** | Scheduled pipelines | Scheduled jobs |
| **Cost** | Included in GitLab | Free (self-hosted) |
| **Learning Curve** | Medium (YAML) | Higher (Groovy) |
| **Enterprise Features** | Built-in | Via plugins |

---

## Further Learning

- GitLab CI/CD Documentation: https://docs.gitlab.com/ee/ci/
- GitLab Runner: https://docs.gitlab.com/runner/
- GitLab Environments: https://docs.gitlab.com/ee/ci/environments/
- Protected Environments: https://docs.gitlab.com/ee/ci/environments/protected_environments.html
- GitLab Approvals: https://docs.gitlab.com/ee/user/project/merge_requests/approvals/

