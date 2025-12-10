# Terraform CI/CD Best Practices & Complete Guide

## 1. Plan-Approval-Apply Workflow Architecture

The gold standard for safe Terraform deployments.

**Why this pattern:**
- ✓ Separates plan review from execution (audit trail)
- ✓ Allows code review before infrastructure changes
- ✓ Enables rollback if issues found in plan
- ✓ Ensures all approvers see same plan being applied
- ✓ Prevents race conditions (plan file artifacts)

**Implementation:**
```groovy
// Jenkins example
pipeline {
    stages {
        stage('Plan') {
            steps {
                sh '''
                    terraform init
                    terraform plan -out=tfplan -json > plan.json
                '''
            }
        }
        
        stage('Review') {
            steps {
                // Display plan summary
                sh 'terraform show -no-color tfplan > PLAN_OUTPUT.txt'
                archiveArtifacts artifacts: 'PLAN_OUTPUT.txt'
                
                // Generate detailed report
                sh '''
                    echo "=== RESOURCE CHANGES ===" > plan-summary.txt
                    jq '.resource_changes[] | {address, actions, change}' plan.json >> plan-summary.txt
                '''
            }
        }
        
        stage('Approval') {
            steps {
                // Human review and approval
                input(
                    id: 'TFApproval',
                    message: 'Review plan and approve?',
                    ok: 'Deploy'
                )
            }
        }
        
        stage('Apply') {
            steps {
                // Apply ONLY the approved plan
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }
}
```

**GitLab equivalent:**
```yaml
stages:
  - plan
  - approve
  - apply

plan:
  stage: plan
  script:
    - terraform init
    - terraform plan -out=tfplan -json > plan.json
  artifacts:
    paths:
      - tfplan
      - plan.json

approval:
  stage: approve
  script:
    - terraform show tfplan > PLAN_OUTPUT.txt
  artifacts:
    paths:
      - PLAN_OUTPUT.txt
  when: manual

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
```

---

## 2. State Management in CI/CD

Proper state management is critical for multi-person, multi-pipeline deployments.

**Critical rules:**
1. **Never commit .tfstate files to Git**
2. **Always use remote backend (S3, Azure Storage, TF Cloud)**
3. **Always enable state locking (DynamoDB, Azure Table Storage)**
4. **Always encrypt state at rest**
5. **Always encrypt state in transit**

**S3 + DynamoDB backend setup:**
```hcl
# backend.hcl (NOT committed to Git)
bucket         = "terraform-state-prod"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true
```

**Create DynamoDB lock table:**
```hcl
resource "aws_dynamodb_table" "terraform_locks" {
  name           = "terraform-locks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State Locking"
  }
}
```

**CI/CD state locking behavior:**
```bash
# When job starts:
# 1. Acquire lock (write to DynamoDB)
# 2. Read current state from S3
# 3. Run terraform operations

# If another job tries to run simultaneously:
# Error: Resource Lock Error - another terraform operation already in progress

# When job completes:
# 4. Release lock
# 5. Upload updated state to S3

# This prevents concurrent modifications that corrupt state
```

**State isolation by environment:**
```hcl
# backend.hcl - interpolate environment from CI/CD
bucket         = "terraform-state-${ENVIRONMENT}"
key            = "${ENVIRONMENT}/terraform.tfstate"
dynamodb_table = "terraform-locks"
```

**State backup strategy:**
```yaml
# GitLab CI/CD - automatic backup
backup:state:
  stage: backup
  script:
    - |
      aws s3 cp \
        s3://terraform-state-prod/prod/terraform.tfstate \
        s3://terraform-backups/prod/terraform.tfstate.$(date +%Y%m%d_%H%M%S)
  schedule:
    cron: "0 2 * * *"  # Daily at 2 AM
```

---

## 3. Credential & Secret Management

Never hardcode credentials in pipelines.

**Options ranked (best to worst):**

**1st Choice: IAM Roles (Most Secure)**
```groovy
// Jenkins agent runs on EC2 with attached IAM role
// No credentials needed - AWS SDK automatically uses instance credentials

pipeline {
    agent { label 'terraform-ec2-agent' }
    
    stages {
        stage('Deploy') {
            steps {
                sh '''
                    # Uses IAM role credentials automatically
                    aws sts get-caller-identity
                    terraform apply -auto-approve
                '''
            }
        }
    }
}
```

**2nd Choice: OIDC Token (GitLab/GitHub)**
```yaml
# GitLab - Use OpenID Connect to get temporary AWS credentials
# No long-lived credentials stored anywhere

image: hashicorp/terraform:latest

variables:
  AWS_ROLE_ARN: arn:aws:iam::123456789012:role/gitlab-terraform-role
  AWS_SESSION_NAME: "terraform-ci-${CI_COMMIT_SHA}"
  AWS_WEB_IDENTITY_TOKEN_FILE: /tmp/web_identity_token

before_script:
  - echo $CI_JOB_JWT_V2 > ${AWS_WEB_IDENTITY_TOKEN_FILE}

deploy:
  stage: deploy
  script:
    - terraform apply -auto-approve
```

**3rd Choice: Vault (HashiCorp Vault)**
```groovy
pipeline {
    agent any
    
    stages {
        stage('Get Credentials') {
            steps {
                withVault([
                    vaultUrl: 'https://vault.example.com',
                    vaultCredentialId: 'vault-token',
                    engineVersion: 2,
                    paths: [[
                        secretPath: 'secret/data/aws',
                        secretValues: [
                            [envVar: 'AWS_ACCESS_KEY_ID', vaultKey: 'access_key'],
                            [envVar: 'AWS_SECRET_ACCESS_KEY', vaultKey: 'secret_key']
                        ]
                    ]]
                ]) {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}
```

**4th Choice: CI/CD Masked Variables (Acceptable)**
```yaml
# GitLab - Use protected, masked variables
# Only accessible in protected branches/pipelines
# Values masked in logs

variables:
  AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID  # Protected variable
  AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY  # Protected variable

deploy:
  stage: deploy
  only:
    - main  # Protected branch only
  script:
    - terraform apply -auto-approve
```

**✗ Never do this:**
```groovy
// WRONG: Hardcoded credentials
environment {
    AWS_ACCESS_KEY_ID = 'AKIAIOSFODNN7EXAMPLE'
    AWS_SECRET_ACCESS_KEY = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
}

// WRONG: Credentials in Git
sh '''
    export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
    export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
'''
```

---

## 4. Environment Protection & Approval Rules

Different approval requirements for different environments.

**Environment protection matrix:**
```
Environment  | Approval Required | Approver Count | Auto-Destroy
-------------|------------------|----------------|-------------
Development  | No               | N/A            | Yes (manual)
Staging      | Yes (1 person)   | 1              | No
Production   | Yes (2+ people)  | 2+             | No (protected)
```

**Implement in Jenkins:**
```groovy
pipeline {
    agent any
    
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'])
        booleanParam(name: 'REQUIRE_APPROVAL', defaultValue: true)
    }
    
    stages {
        stage('Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }
        
        stage('Approval') {
            when {
                expression {
                    // Always approve prod
                    // Optional approval for lower envs
                    return params.ENVIRONMENT == 'prod' || params.REQUIRE_APPROVAL
                }
            }
            steps {
                input(
                    id: "Approval_${params.ENVIRONMENT}",
                    message: "Approve ${params.ENVIRONMENT} deployment?",
                    submitter: params.ENVIRONMENT == 'prod' ? 'terraform-admins' : 'developers'
                )
            }
        }
        
        stage('Apply') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }
}
```

**Implement in GitLab:**
```yaml
deploy:dev:
  environment:
    name: development
    deployment_tier: development
  only:
    - develop

deploy:staging:
  environment:
    name: staging
    deployment_tier: staging
    auto_stop_in: 1 week
  when: manual  # Require manual trigger

deploy:prod:
  environment:
    name: production
    deployment_tier: production
    # Protection rules (configure in UI):
    # - Required approvals: 2
    # - Approver group: terraform-admins
    # - Access: Maintainers only
  only:
    - main
  when: manual
```

---

## 5. Security Scanning in Pipeline

Scan infrastructure code before deployment.

**Tools to integrate:**
- **tfsec:** Terraform security scanner
- **checkov:** Policy as code
- **trivy:** Vulnerability scanner
- **terrascan:** Terraform security scanner

**tfsec integration:**
```yaml
# GitLab CI/CD
security:scan:
  stage: validate
  image: aquasec/tfsec-ci:latest
  script:
    - tfsec . -f json > tfsec-report.json
    - tfsec . -f sarif > tfsec-report.sarif
  artifacts:
    reports:
      sast: tfsec-report.sarif
    paths:
      - tfsec-report.json
  allow_failure: true  # Don't block pipeline, just warn
```

**Checkov integration:**
```yaml
# GitLab CI/CD
policy:check:
  stage: validate
  image: bridgecrewio/checkov:latest
  script:
    - checkov -d . --framework terraform --check CKV_AWS_1
    - checkov -d . --framework terraform --output json > checkov-report.json
  artifacts:
    paths:
      - checkov-report.json
```

**Jenkins security scanning:**
```groovy
stage('Security Scan') {
    parallel {
        stage('tfsec') {
            steps {
                sh '''
                    docker run --rm -v $(pwd):/src aquasec/tfsec-ci \
                        tfsec /src -f json > tfsec-report.json
                '''
            }
        }
        
        stage('checkov') {
            steps {
                sh '''
                    docker run --rm -v $(pwd):/src bridgecrewio/checkov \
                        -d /src --framework terraform \
                        --output json > checkov-report.json
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: '*-report.json'
        }
    }
}
```

**Break pipeline on critical findings:**
```bash
#!/bin/bash
# Check for critical issues

tfsec . -f json > tfsec-report.json

# Count critical issues
CRITICAL=$(jq '[.[] | select(.severity == "CRITICAL")] | length' tfsec-report.json)

if [ $CRITICAL -gt 0 ]; then
    echo "❌ Found $CRITICAL critical security issues"
    exit 1
fi

echo "✓ Security scan passed"
```

---

## 6. Artifact Management

Manage Terraform plans, outputs, and reports across pipeline stages.

**Plan artifact lifecycle:**
```groovy
stage('Plan') {
    steps {
        sh 'terraform plan -out=tfplan -json > plan.json'
        
        // Archive for downstream jobs
        archiveArtifacts(
            artifacts: 'tfplan,plan.json,*.txt',
            allowEmptyArchive: false
        )
    }
}

stage('Apply') {
    steps {
        // Restore plan artifact from upstream job
        copyArtifacts(
            projectName: env.JOB_NAME,
            selector: specific('${BUILD_NUMBER}'),
            target: '.'
        )
        
        sh 'terraform apply -auto-approve tfplan'
    }
}
```

**Output artifact management:**
```groovy
stage('Export Outputs') {
    steps {
        sh '''
            # Export all outputs
            terraform output -json > outputs.json
            
            # Export specific values
            terraform output -raw vpc_id > vpc_id.txt
            terraform output -json instance_ids > instance_ids.json
            
            # Create human-readable report
            cat > deployment-report.txt <<EOF
Deployment Report
=================
Timestamp: $(date)
Commit: ${GIT_COMMIT}
Deployer: ${BUILD_USER}

Infrastructure Summary:
$(jq -r 'to_entries[] | "\(.key): \(.value.value)"' outputs.json)
EOF
        '''
        
        // Archive artifacts for 30 days
        archiveArtifacts(
            artifacts: 'outputs.json,deployment-report.txt',
            allowEmptyArchive: false,
            defaultExcludes: false,
            onlyIfSuccessful: true
        )
    }
}
```

**Retention policy:**
```yaml
# GitLab CI/CD
apply:
  stage: apply
  artifacts:
    paths:
      - terraform/outputs.json
      - terraform/plan.json
    expire_in: 30 days  # Delete after 30 days
  dependencies:
    - plan
```

---

## 7. Drift Detection & Remediation

Detect when infrastructure diverges from Terraform code.

**Scheduled drift detection:**
```yaml
# GitLab - Run hourly
drift:check:
  stage: check
  image: hashicorp/terraform:latest
  script:
    - terraform init
    - terraform plan -json > drift.json
    
    # Check for unmanaged changes
    - |
      DRIFT=$(jq '.resource_changes | length' drift.json)
      
      if [ "$DRIFT" -gt 0 ]; then
        echo "⚠️ Drift detected: $DRIFT resources"
        
        # Generate report
        jq '.resource_changes[] | 
            select(.change.actions[] | select(. != "no-op")) | 
            {address, actions, change}' drift.json > drift-report.json
        
        # Notify
        curl -X POST https://slack.com/api/chat.postMessage \
          -d "text=Terraform drift detected in production" \
          -d "channel=infra-alerts"
      fi
  
  artifacts:
    paths:
      - drift.json
      - drift-report.json
    expire_in: 7 days
  
  schedule:
    cron: "0 * * * *"  # Every hour
```

**Automatic drift remediation:**
```groovy
// Jenkins - Auto-remediate for dev, alert for prod

stage('Drift Remediation') {
    when {
        expression { return DRIFT_DETECTED }
    }
    steps {
        script {
            if (env.ENVIRONMENT == 'dev') {
                // Auto-remediate dev
                sh 'terraform apply -auto-approve'
                echo "✓ Dev drift automatically remediated"
            } else if (env.ENVIRONMENT == 'prod') {
                // Alert for prod, require approval
                input("Approve drift remediation for PRODUCTION?")
                sh 'terraform apply -auto-approve'
            }
        }
    }
}
```

---

## 8. Rollback & Disaster Recovery

Recover from failed deployments quickly.

**Rollback strategy 1: Plan + Apply separation**
```bash
# Always apply from saved plan, never live destroy
terraform apply -auto-approve tfplan  # Safe - reproducible

# NEVER do this in production:
terraform apply  # Dangerous - runs new plan each time
```

**Rollback strategy 2: State file backup**
```bash
# Before apply, save backup
cp terraform.tfstate terraform.tfstate.backup

# If apply fails:
cp terraform.tfstate.backup terraform.tfstate

# Or restore from S3
aws s3 cp \
    s3://terraform-backups/prod/terraform.tfstate.backup \
    terraform.tfstate

terraform apply -refresh=false -auto-approve
```

**Rollback strategy 3: Revert commit**
```groovy
post {
    failure {
        script {
            if (env.ENVIRONMENT == 'prod') {
                // Create rollback branch
                sh '''
                    git checkout -b rollback/${BUILD_NUMBER}
                    git revert ${GIT_COMMIT}
                    git push origin rollback/${BUILD_NUMBER}
                '''
                
                // Notify team
                emailext(
                    subject: "❌ Terraform deployment failed - rollback required",
                    body: "See rollback branch: rollback/${BUILD_NUMBER}",
                    to: "terraform-admins@example.com"
                )
            }
        }
    }
}
```

**Rollback strategy 4: Terraform destroy + re-create**
```bash
# For stateless resources (ASGs, ALBs):
terraform destroy -target=aws_autoscaling_group.main
terraform apply -auto-approve

# For stateful resources (RDS, S3):
# Requires snapshots/backups for recovery
terraform destroy -target=aws_db_instance.prod -refresh=false
# Manually restore from snapshot
terraform apply -auto-approve  # Recreate from snapshot
```

---

## 9. Post-Deployment Validation

Verify infrastructure is healthy after deployment.

**Health check stage:**
```groovy
stage('Post-Deployment Validation') {
    steps {
        sh '''
            # Extract outputs
            VPC_ID=$(terraform output -raw vpc_id)
            INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]')
            
            echo "Validating deployment..."
            
            # Check EC2 instances
            for INSTANCE in $INSTANCE_IDS; do
                STATE=$(aws ec2 describe-instances \
                    --instance-ids $INSTANCE \
                    --query 'Reservations[0].Instances[0].State.Name' \
                    --output text)
                
                if [ "$STATE" != "running" ]; then
                    echo "❌ Instance $INSTANCE not running (state: $STATE)"
                    exit 1
                fi
                
                echo "✓ Instance $INSTANCE is running"
            done
            
            # Check RDS database
            DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo "")
            if [ -n "$DB_ENDPOINT" ]; then
                if nc -z $DB_ENDPOINT 5432 2>/dev/null; then
                    echo "✓ RDS database is responding"
                else
                    echo "⚠️ RDS database not responding yet (may still be starting)"
                fi
            fi
            
            # Check security groups
            echo "✓ Validating security group rules..."
            
            echo ""
            echo "=== DEPLOYMENT VALIDATION PASSED ==="
        '''
    }
}
```

**Application health checks:**
```groovy
stage('Application Health Check') {
    steps {
        sh '''
            LOAD_BALANCER=$(terraform output -raw load_balancer_dns)
            
            # Wait for ALB to be healthy
            echo "Waiting for ALB to be ready..."
            
            max_attempts=30
            attempt=0
            
            while [ $attempt -lt $max_attempts ]; do
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                    http://${LOAD_BALANCER}/health)
                
                if [ "$HTTP_CODE" = "200" ]; then
                    echo "✓ Application is healthy (HTTP $HTTP_CODE)"
                    exit 0
                fi
                
                echo "Attempt $((attempt+1))/$max_attempts: HTTP $HTTP_CODE"
                sleep 5
                attempt=$((attempt+1))
            done
            
            echo "❌ Application failed health check"
            exit 1
        '''
    }
}
```

---

## 10. Complete CI/CD Pipeline Example

End-to-end production pipeline:
```groovy
// Jenkinsfile - Full production pipeline

pipeline {
    agent { label 'terraform-prod' }
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
        booleanParam(
            name: 'SKIP_APPROVAL',
            defaultValue: false,
            description: 'Skip approval (dev only)'
        )
    }
    
    environment {
        AWS_REGION = 'us-east-1'
        TF_VERSION = '1.5.0'
        TF_INPUT = 'false'
        TF_IN_AUTOMATION = 'true'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --pretty=%H'
            }
        }
        
        stage('Validate Environment') {
            steps {
                script {
                    if (params.ENVIRONMENT == 'prod' && params.SKIP_APPROVAL) {
                        error('❌ Cannot skip approval for production')
                    }
                }
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh '''
                    cat > backend-config.hcl <<EOF
bucket         = "terraform-state-${ENVIRONMENT}"
key            = "${ENVIRONMENT}/terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "terraform-locks"
encrypt        = true
EOF

                    terraform init -backend-config=backend-config.hcl
                '''
            }
        }
        
        stage('Format & Validate') {
            parallel {
                stage('Format Check') {
                    steps {
                        sh 'terraform fmt -check -recursive'
                    }
                }
                
                stage('Validate') {
                    steps {
                        sh 'terraform validate'
                    }
                }
                
                stage('Security Scan') {
                    steps {
                        sh '''
                            docker run --rm -v $(pwd):/src \
                                aquasec/tfsec-ci tfsec /src
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Plan') {
            steps {
                sh '''
                    terraform plan \
                        -var-file="environments/${ENVIRONMENT}.tfvars" \
                        -out=tfplan \
                        -json > plan.json
                    
                    terraform show -no-color tfplan > PLAN_OUTPUT.txt
                '''
                
                archiveArtifacts artifacts: 'PLAN_OUTPUT.txt,plan.json'
            }
        }
        
        stage('Plan Review') {
            steps {
                sh '''
                    echo "=== RESOURCE CHANGES ==="
                    jq '.resource_changes[] | {address, actions}' plan.json
                '''
            }
        }
        
        stage('Approval') {
            when {
                expression {
                    return params.ENVIRONMENT == 'prod' || !params.SKIP_APPROVAL
                }
            }
            steps {
                input(
                    id: "Approval_${params.ENVIRONMENT}",
                    message: "Deploy to ${params.ENVIRONMENT}?",
                    ok: 'Deploy',
                    submitter: params.ENVIRONMENT == 'prod' ? 'terraform-admins' : ''
                )
            }
        }
        
        stage('Terraform Apply') {
            steps {
                sh '''
                    terraform apply -auto-approve tfplan
                    
                    terraform output -json > outputs.json
                '''
                
                archiveArtifacts artifacts: 'outputs.json'
            }
        }
        
        stage('Post-Deployment Validation') {
            steps {
                sh '''
                    echo "Validating deployment..."
                    
                    INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]')
                    
                    for INSTANCE in $INSTANCE_IDS; do
                        STATE=$(aws ec2 describe-instances \
                            --instance-ids $INSTANCE \
                            --query 'Reservations[0].Instances[0].State.Name' \
                            --output text)
                        
                        if [ "$STATE" = "running" ]; then
                            echo "✓ Instance $INSTANCE is running"
                        else
                            echo "❌ Instance $INSTANCE status: $STATE"
                            exit 1
                        fi
                    done
                '''
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
        
        success {
            script {
                if (params.ENVIRONMENT == 'prod') {
                    emailext(
                        subject: "✓ Production Terraform Deployment Successful",
                        body: "Deployment completed successfully",
                        to: "terraform-admins@example.com"
                    )
                }
            }
        }
        
        failure {
            script {
                if (params.ENVIRONMENT == 'prod') {
                    emailext(
                        subject: "❌ Production Terraform Deployment FAILED",
                        body: "Check logs: ${BUILD_URL}console",
                        to: "terraform-admins@example.com"
                    )
                }
            }
        }
    }
}
```

---

## Summary Checklist

**Before going to production, ensure:**
- [ ] Remote state with locking enabled
- [ ] Plan review + approval process
- [ ] Security scanning (tfsec/checkov)
- [ ] Credentials via IAM roles or OIDC
- [ ] Environment protection rules
- [ ] Destroy protection on prod resources
- [ ] Artifact archival for audit trail
- [ ] Drift detection scheduled
- [ ] Post-deployment validation
- [ ] Rollback procedures tested
- [ ] State backups automated
- [ ] Team trained on pipelines

