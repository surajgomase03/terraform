# Jenkins Terraform CI/CD Guide

## Q1: How do you set up a Jenkins pipeline for Terraform?

**Answer:**
Jenkins pipelines automate Terraform workflow: init → plan → approval → apply.

**Basic Jenkinsfile structure:**
```groovy
pipeline {
    agent { label 'terraform-agent' }
    
    environment {
        AWS_REGION = 'us-east-1'
        TF_INPUT = 'false'
        TF_IN_AUTOMATION = 'true'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Terraform Init') {
            steps {
                sh 'terraform init -backend-config=backend.hcl'
            }
        }
        
        stage('Terraform Plan') {
            steps {
                sh 'terraform plan -out=tfplan'
            }
        }
        
        stage('Approval') {
            steps {
                input 'Approve Terraform apply?'
            }
        }
        
        stage('Terraform Apply') {
            steps {
                sh 'terraform apply -auto-approve tfplan'
            }
        }
    }
}
```

**Key Jenkins features:**
- **Pipeline as Code:** Jenkinsfile in Git
- **Stages:** Organized workflow steps
- **Parallel Execution:** Run tasks concurrently
- **Credentials:** Secure secret management
- **Artifacts:** Save plan/output files
- **Input/Approval:** Manual confirmation steps
- **Post Actions:** Cleanup, notifications

---

## Q2: How do you manage AWS credentials in Jenkins?

**Answer:**
Jenkins provides multiple secure methods for AWS credential management.

**Option 1: Jenkins Credentials Plugin**
```groovy
pipeline {
    agent any
    
    environment {
        // Bind AWS credentials
        AWS_CREDS = credentials('aws-terraform-credentials')
        AWS_ACCESS_KEY_ID = "${AWS_CREDS_USR}"
        AWS_SECRET_ACCESS_KEY = "${AWS_CREDS_PSW}"
    }
    
    stages {
        stage('Example') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }
    }
}
```

**Option 2: IAM Role (Recommended for EC2 agents)**
```groovy
// Jenkins agent runs on EC2 instance with IAM role attached
// No credentials needed - automatic!

pipeline {
    agent { label 'terraform-ec2-agent' }
    
    stages {
        stage('Deploy') {
            steps {
                // Uses EC2 instance IAM role automatically
                sh 'aws sts get-caller-identity'
            }
        }
    }
}
```

**Option 3: withAWS Block**
```groovy
pipeline {
    agent any
    
    stages {
        stage('Deploy') {
            steps {
                withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
                    sh '''
                        terraform init
                        terraform apply -auto-approve
                    '''
                }
            }
        }
    }
}
```

**Option 4: Vault Integration**
```groovy
pipeline {
    agent any
    
    environment {
        VAULT_ADDR = 'https://vault.example.com'
        VAULT_NAMESPACE = 'admin'
    }
    
    stages {
        stage('Get AWS Credentials from Vault') {
            steps {
                withVault([
                    vaultUrl: 'https://vault.example.com',
                    vaultCredentialId: 'vault-token',
                    engineVersion: 2,
                    paths: [[secretPath: 'secret/data/aws', secretValues: [
                        [envVar: 'AWS_ACCESS_KEY_ID', vaultKey: 'access_key'],
                        [envVar: 'AWS_SECRET_ACCESS_KEY', vaultKey: 'secret_key']
                    ]]]
                ]) {
                    sh 'terraform apply -auto-approve'
                }
            }
        }
    }
}
```

**Best practices:**
- ✓ Use IAM roles on EC2 agents (no keys to manage)
- ✓ Use Jenkins credentials plugin (encrypted storage)
- ✓ Use Vault for sensitive environments
- ✓ Rotate credentials every 90 days
- ✓ Use temporary STS credentials when possible
- ✓ Audit credential access

---

## Q3: How do you configure the Terraform backend in Jenkins pipeline?

**Answer:**
Backend configuration tells Terraform where to store state remotely (S3 + DynamoDB).

**Backend configuration methods:**

**Option 1: Backend config file**
```groovy
stage('Terraform Init') {
    steps {
        sh '''
            cat > backend-config.hcl <<EOF
bucket         = "terraform-state-prod"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"
encrypt        = true
EOF

            terraform init -backend-config=backend-config.hcl
        '''
    }
}
```

**Option 2: Command-line flags**
```groovy
stage('Terraform Init') {
    steps {
        sh '''
            terraform init \
                -backend-config="bucket=terraform-state" \
                -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
                -backend-config="region=us-east-1" \
                -backend-config="dynamodb_table=terraform-locks" \
                -backend-config="encrypt=true"
        '''
    }
}
```

**Option 3: Environment-specific config**
```groovy
stage('Terraform Init') {
    steps {
        sh '''
            BUCKET="terraform-state-${ENVIRONMENT}"
            
            terraform init \
                -backend-config="bucket=${BUCKET}" \
                -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
                -reconfigure
        '''
    }
}
```

**Backend state locking (DynamoDB):**
```hcl
# backend.hcl
bucket         = "terraform-state"
key            = "prod/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "terraform-locks"  # Prevents concurrent modifications
encrypt        = true               # KMS encryption
```

---

## Q4: How do you handle plan approval in Jenkins?

**Answer:**
Manual approval gates prevent accidental deployments and ensure review.

**Basic approval:**
```groovy
stage('Plan Review & Approval') {
    steps {
        // Display plan for review
        sh 'terraform show -no-color tfplan > plan-output.txt'
        
        // Archive plan output
        archiveArtifacts artifacts: 'plan-output.txt'
        
        // Manual approval (blocking)
        input(
            id: 'TerraformApproval',
            message: 'Approve Terraform apply?',
            ok: 'Deploy'
        )
    }
}
```

**Approval with conditions:**
```groovy
stage('Approval') {
    when {
        expression {
            // Always require approval for prod
            return env.ENVIRONMENT == 'prod'
        }
    }
    steps {
        input(
            id: 'ProdApproval',
            message: "Deploy to PRODUCTION?",
            submitter: 'terraform-admins'  // Only specific group
        )
    }
}
```

**Approval with parameters:**
```groovy
stage('Review & Approve') {
    steps {
        def userInput = input(
            id: 'Approval',
            message: 'Review plan and approve',
            parameters: [
                booleanParam(
                    defaultValue: false,
                    description: 'Approve and continue',
                    name: 'APPROVE'
                ),
                string(
                    defaultValue: 'No comments',
                    description: 'Approval comments',
                    name: 'COMMENTS'
                )
            ]
        )
        
        if (!userInput) {
            error '❌ Deployment rejected'
        }
        
        echo "Comments: ${COMMENTS}"
    }
}
```

**Approval with team notification:**
```groovy
stage('Approval') {
    steps {
        // Notify team of pending approval
        sh '''
            curl -X POST https://slack.com/api/chat.postMessage \
                -H 'Content-Type: application/json' \
                -d '{
                    "channel": "#deployments",
                    "text": "Terraform plan ready for approval: '$BUILD_URL'"
                }'
        '''
        
        // Wait for approval
        timeout(time: 24, unit: 'HOURS') {
            input 'Approve deployment?'
        }
    }
}
```

**Prevent accidental apply without plan:**
```groovy
stage('Terraform Apply') {
    steps {
        sh '''
            # Only apply from saved plan (not live resources)
            if [ ! -f tfplan ]; then
                echo "ERROR: No plan file found!"
                exit 1
            fi
            
            terraform apply -auto-approve tfplan
        '''
    }
}
```

---

## Q5: How do you set up a Jenkins agent for Terraform?

**Answer:**
Jenkins agents execute pipeline jobs. They need Terraform and AWS tools.

**Agent requirements:**
```
✓ Terraform CLI (1.0+)
✓ AWS CLI v2
✓ Git
✓ jq (JSON processing)
✓ tfsec (optional, security scanning)
✓ bash shell
✓ Docker (optional)
```

**Jenkins agent configuration:**

**Option 1: Dedicated VM agent**
```groovy
pipeline {
    agent {
        label 'terraform-prod'  // Specific agent label
    }
    
    stages {
        stage('Deploy') {
            steps {
                sh 'terraform version'
            }
        }
    }
}
```

**Option 2: Docker agent**
```groovy
pipeline {
    agent {
        docker {
            image 'hashicorp/terraform:latest'
            args '--entrypoint="" --user root'
        }
    }
    
    stages {
        stage('Deploy') {
            steps {
                sh 'terraform --version'
            }
        }
    }
}
```

**Option 3: Custom Docker image**
```dockerfile
# Dockerfile
FROM hashicorp/terraform:latest

RUN apk add --no-cache \
    aws-cli \
    git \
    jq \
    curl

# Install tfsec
RUN wget https://github.com/aquasecurity/tfsec/releases/download/v1.25.0/tfsec-linux-amd64 \
    && chmod +x tfsec-linux-amd64 \
    && mv tfsec-linux-amd64 /usr/local/bin/tfsec

ENTRYPOINT ["/bin/sh"]
```

**Option 4: Agent setup script**
```bash
#!/bin/bash
# Setup Jenkins agent for Terraform

# Install Terraform
curl -s https://releases.hashicorp.com/terraform/1.5.0/terraform_1.5.0_linux_amd64.zip | unzip -d /usr/local/bin

# Install AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

# Install other tools
apt-get install -y git jq curl

# Install tfsec
curl -s https://github.com/aquasecurity/tfsec/releases/download/v1.25.0/tfsec-linux-amd64 \
    -o /usr/local/bin/tfsec && chmod +x /usr/local/bin/tfsec

# Verify installation
terraform --version
aws --version
git --version
```

---

## Q6: How do you handle environment-specific configurations?

**Answer:**
Different environments (dev, staging, prod) need different infrastructure.

**Using tfvars files:**
```groovy
pipeline {
    agent any
    
    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
    }
    
    stages {
        stage('Terraform Plan') {
            steps {
                sh '''
                    terraform plan \
                        -var-file="environments/${ENVIRONMENT}.tfvars" \
                        -out=tfplan
                '''
            }
        }
        
        stage('Terraform Apply') {
            steps {
                sh '''
                    terraform apply \
                        -var-file="environments/${ENVIRONMENT}.tfvars" \
                        -auto-approve tfplan
                '''
            }
        }
    }
}
```

**Environment-specific tfvars:**
```hcl
# environments/dev.tfvars
environment        = "dev"
instance_count     = 1
instance_type      = "t3.micro"
backup_retention   = 7
enable_monitoring  = false

# environments/prod.tfvars
environment        = "prod"
instance_count     = 3
instance_type      = "t3.medium"
backup_retention   = 30
enable_monitoring  = true
```

**Using workspace feature:**
```groovy
stage('Terraform Select Workspace') {
    steps {
        sh '''
            terraform workspace select ${ENVIRONMENT} || \
            terraform workspace new ${ENVIRONMENT}
        '''
    }
}
```

---

## Q7: How do you implement destroy protection for production?

**Answer:**
Prevent accidental destruction of production infrastructure.

**Destroy prevention patterns:**

**Option 1: Parameter validation**
```groovy
parameters {
    booleanParam(name: 'DESTROY', defaultValue: false)
}

stage('Validate Destroy') {
    steps {
        script {
            if (params.DESTROY && env.ENVIRONMENT == 'prod') {
                error('❌ Cannot destroy production!')
            }
        }
    }
}
```

**Option 2: Lifecycle management in Terraform**
```hcl
resource "aws_db_instance" "prod" {
    # ... configuration
    
    lifecycle {
        prevent_destroy = var.environment == "prod"
    }
}
```

**Option 3: Explicit approval for destroy**
```groovy
stage('Confirm Destroy') {
    when {
        expression { params.DESTROY }
    }
    steps {
        def confirm = input(
            id: 'DestroyConfirm',
            message: "⚠️ CONFIRM DESTROY of ${ENVIRONMENT}?",
            parameters: [
                string(
                    defaultValue: '',
                    description: 'Type environment name to confirm',
                    name: 'CONFIRM_TEXT'
                )
            ]
        )
        
        if (confirm != params.ENVIRONMENT) {
            error('❌ Destroy cancelled - confirmation mismatch')
        }
    }
}

stage('Terraform Destroy') {
    when {
        expression {
            return params.DESTROY && env.ENVIRONMENT == 'dev'
        }
    }
    steps {
        sh 'terraform destroy -auto-approve'
    }
}
```

---

## Q8: How do you export Terraform outputs for downstream jobs?

**Answer:**
Pipeline outputs needed by other jobs or applications.

**Export outputs:**
```groovy
stage('Export Outputs') {
    steps {
        sh '''
            # Export as JSON
            terraform output -json > outputs.json
            
            # Export specific values
            terraform output -raw vpc_id > vpc_id.txt
            terraform output -json instance_ids > instance_ids.json
            
            # Create environment file
            cat > deployment-info.txt <<EOF
VPC_ID=$(terraform output -raw vpc_id)
INSTANCE_COUNT=$(terraform output -raw instance_count)
DB_ENDPOINT=$(terraform output -raw database_endpoint)
DEPLOYMENT_DATE=$(date)
EOF
        '''
        
        // Archive for download
        archiveArtifacts artifacts: 'outputs.json,deployment-info.txt'
    }
}
```

**Consume outputs in downstream job:**
```groovy
stage('Use Terraform Outputs') {
    steps {
        // Copy artifacts from upstream job
        copyArtifacts(
            projectName: 'terraform-deploy',
            selector: lastSuccessful(),
            target: 'artifacts'
        )
        
        // Read and use outputs
        sh '''
            VPC_ID=$(jq -r '.vpc_id.value' artifacts/outputs.json)
            echo "VPC ID: ${VPC_ID}"
            
            # Use in next stage (e.g., run tests)
            ./run-tests.sh --vpc-id ${VPC_ID}
        '''
    }
}
```

---

## Q9: How do you implement rollback for failed deployments?

**Answer:**
Recover from failed Terraform applies quickly.

**Rollback strategy:**
```groovy
stage('Terraform Apply') {
    steps {
        sh '''
            # Save previous state as backup
            cp terraform.tfstate terraform.tfstate.backup
            
            # Apply changes
            terraform apply -auto-approve tfplan || {
                echo "Apply failed, rolling back..."
                cp terraform.tfstate.backup terraform.tfstate
                exit 1
            }
        '''
    }
}

post {
    failure {
        script {
            if (fileExists('terraform.tfstate.backup')) {
                sh '''
                    echo "Rolling back to previous state..."
                    cp terraform.tfstate.backup terraform.tfstate
                    
                    # Re-apply previous state
                    terraform apply -auto-approve -refresh=false
                '''
            }
        }
    }
}
```

**For remote state:**
```groovy
post {
    failure {
        sh '''
            # Restore from S3 backup
            aws s3 cp \
                s3://terraform-backups/${ENVIRONMENT}/terraform.tfstate.backup \
                terraform.tfstate
            
            terraform apply -auto-approve
        '''
    }
}
```

---

## Q10: Jenkins Terraform Best Practices Checklist

**✓ Do:**
- [ ] Use IAM roles for EC2 agents (no hardcoded keys)
- [ ] Always use remote backend (S3 + DynamoDB)
- [ ] Require approval for production
- [ ] Save and review plans before apply
- [ ] Use tfvars for environment-specific config
- [ ] Scan code with tfsec/checkov
- [ ] Archive plan/output artifacts
- [ ] Implement destroy protection
- [ ] Use docker agents for isolation
- [ ] Log all pipeline executions
- [ ] Implement rollback procedures
- [ ] Regular state backups

**✗ Don't:**
- [ ] Hardcode AWS credentials
- [ ] Use local state
- [ ] Auto-approve production
- [ ] Run terraform destroy without approval
- [ ] Skip security scanning
- [ ] Commit tfstate files
- [ ] Share credentials between jobs
- [ ] Run multiple applies concurrently
- [ ] Ignore plan review
- [ ] Forget to backup state
- [ ] Use root/admin credentials
- [ ] Skip post-deployment validation

---

## Quick Reference Commands

```bash
# Jenkinsfile validation
jenkins-cli validate-jenkins.jelly < Jenkinsfile

# Trigger Jenkins job from CLI
java -jar jenkins-cli.jar -s http://jenkins:8080 build my-job \
  -p ENVIRONMENT=prod

# View Jenkins logs
tail -f /var/log/jenkins/jenkins.log

# Test Terraform in Jenkins environment
docker run -v $(pwd):/workspace hashicorp/terraform init

# Check agent connectivity
curl -s http://jenkins:8080/computer/agent-name/api/json
```

---

## Further Learning

- Jenkins Documentation: https://www.jenkins.io/doc/
- Jenkins Terraform Plugin: https://plugins.jenkins.io/terraform/
- Groovy Pipeline: https://www.jenkins.io/doc/book/pipeline/
- Jenkins Credentials: https://plugins.jenkins.io/credentials/
- AWS Jenkins Plugin: https://plugins.jenkins.io/aws-credentials/

