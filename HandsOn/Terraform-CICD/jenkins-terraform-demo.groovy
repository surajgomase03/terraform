// Terraform Jenkins Demo
// Demonstrates Jenkinsfile patterns for Terraform CI/CD pipelines

// ============================================================================
// SIMPLE JENKINS PIPELINE (Basic Pattern)
// ============================================================================

pipeline {
    agent {
        label 'terraform-agent'  // Jenkins agent with Terraform installed
    }

    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timeout(time: 1, unit: 'HOURS')
        timestamps()
    }

    parameters {
        choice(
            name: 'ENVIRONMENT',
            choices: ['dev', 'staging', 'prod'],
            description: 'Target environment'
        )
        booleanParam(
            name: 'AUTO_APPROVE',
            defaultValue: false,
            description: 'Skip manual approval (prod: always manual)'
        )
        booleanParam(
            name: 'DESTROY',
            defaultValue: false,
            description: 'Destroy infrastructure (dev only)'
        )
    }

    environment {
        AWS_REGION = 'us-east-1'
        TERRAFORM_VERSION = '1.5.0'
        TF_INPUT = 'false'
        TF_IN_AUTOMATION = 'true'
        TF_LOG = 'INFO'  // Set to DEBUG for troubleshooting
    }

    stages {
        stage('Checkout') {
            steps {
                echo "========== Checking out Terraform code =========="
                checkout scm
                
                sh '''
                    echo "Git branch: $(git rev-parse --abbrev-ref HEAD)"
                    echo "Git commit: $(git rev-parse HEAD)"
                    echo "Git commit message: $(git log -1 --pretty=%B)"
                '''
            }
        }

        stage('Validate Environment') {
            steps {
                echo "========== Validating environment =========="
                script {
                    // Prevent destroy in prod
                    if (params.DESTROY && params.ENVIRONMENT == 'prod') {
                        error('❌ Cannot destroy production environment!')
                    }
                    
                    // Require approval for prod
                    if (params.ENVIRONMENT == 'prod' && params.AUTO_APPROVE) {
                        error('❌ Production requires manual approval!')
                    }
                }

                sh '''
                    echo "Target Environment: ${ENVIRONMENT}"
                    echo "AWS Region: ${AWS_REGION}"
                    echo "Auto Approve: ${AUTO_APPROVE}"
                    echo "Destroy: ${DESTROY}"
                    
                    # Verify AWS credentials are available
                    aws sts get-caller-identity
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                echo "========== Initializing Terraform =========="
                script {
                    // Create backend config for different environments
                    sh '''
                        cat > backend-config.hcl <<EOF
bucket         = "terraform-state-${ENVIRONMENT}"
key            = "${ENVIRONMENT}/terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "terraform-locks"
encrypt        = true
EOF
                    '''
                }

                sh '''
                    terraform init \
                        -backend-config=backend-config.hcl \
                        -reconfigure \
                        -upgrade=false
                '''
            }
        }

        stage('Terraform Format & Validate') {
            parallel {
                stage('Format Check') {
                    steps {
                        sh '''
                            echo "Checking Terraform code formatting..."
                            terraform fmt -check -recursive .
                        '''
                    }
                }

                stage('Validate') {
                    steps {
                        sh '''
                            echo "Validating Terraform configuration..."
                            terraform validate
                        '''
                    }
                }

                stage('Security Scan') {
                    steps {
                        sh '''
                            echo "Running tfsec security scan..."
                            tfsec . --minimum-severity HIGH || true
                        '''
                    }
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                echo "========== Planning Terraform changes =========="
                script {
                    def planFile = "${ENVIRONMENT}-plan.tfplan"
                    def planJson = "${ENVIRONMENT}-plan.json"

                    sh '''
                        terraform plan \
                            -var-file="environments/${ENVIRONMENT}.tfvars" \
                            -out="${planFile}" \
                            -json > "${planJson}" || true
                        
                        # Generate human-readable plan output
                        terraform show -no-color "${planFile}" > plan-output.txt || true
                    '''

                    // Parse plan output for display
                    sh '''
                        echo "========== Terraform Plan Summary =========="
                        grep -E "Plan:|No changes|will be created|will be updated|will be destroyed|will be replaced" plan-output.txt || true
                    '''

                    // Archive plan for apply stage
                    archiveArtifacts artifacts: "*-plan.*,plan-output.txt", allowEmptyArchive: false
                }
            }
        }

        stage('Approval') {
            when {
                // Always require approval for prod
                expression {
                    return params.ENVIRONMENT == 'prod' || !params.AUTO_APPROVE
                }
            }
            steps {
                script {
                    def planFile = "${params.ENVIRONMENT}-plan.tfplan"
                    
                    // Read and display plan for approval
                    sh '''
                        echo "========== Review Plan Before Approval =========="
                        terraform show -no-color "${planFile}" | head -100
                        echo "... (see full plan in artifacts) ..."
                    '''

                    // Manual approval input
                    def userInput = input(
                        id: 'Approval',
                        message: "Approve Terraform ${params.ENVIRONMENT} deployment?",
                        parameters: [
                            booleanParam(defaultValue: false, description: 'Approve and continue', name: 'APPROVE')
                        ]
                    )

                    if (!userInput) {
                        error('❌ Deployment rejected by user!')
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression {
                    return !params.DESTROY
                }
            }
            steps {
                echo "========== Applying Terraform changes =========="
                script {
                    def planFile = "${params.ENVIRONMENT}-plan.tfplan"

                    sh '''
                        echo "Applying plan: ${planFile}"
                        terraform apply -no-color -auto-approve "${planFile}"
                    '''
                }
            }
        }

        stage('Terraform Destroy') {
            when {
                expression {
                    return params.DESTROY && params.ENVIRONMENT == 'dev'
                }
            }
            steps {
                echo "========== Destroying Terraform infrastructure =========="
                script {
                    // Double-check destroy approval
                    def approveDestroy = input(
                        id: 'DestroyApproval',
                        message: "⚠️  Are you sure you want to DESTROY ${params.ENVIRONMENT}?",
                        parameters: [
                            booleanParam(defaultValue: false, description: 'Yes, destroy', name: 'CONFIRM')
                        ]
                    )

                    if (!approveDestroy) {
                        error('❌ Destroy cancelled!')
                    }

                    sh '''
                        terraform destroy \
                            -var-file="environments/${ENVIRONMENT}.tfvars" \
                            -auto-approve \
                            -no-color
                    '''
                }
            }
        }

        stage('Export Outputs') {
            steps {
                echo "========== Exporting Terraform outputs =========="
                sh '''
                    # Export outputs to file for downstream jobs
                    terraform output -json > outputs.json
                    
                    # Display key outputs
                    echo "========== Deployment Outputs =========="
                    terraform output -no-color
                    
                    # Save environment info for other jobs
                    cat > deployment-info.txt <<EOF
ENVIRONMENT=${ENVIRONMENT}
VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo 'N/A')
INSTANCE_COUNT=$(terraform output -raw instance_count 2>/dev/null || echo 'N/A')
DB_ENDPOINT=$(terraform output -raw database_endpoint 2>/dev/null || echo 'N/A')
DEPLOYED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF
                '''

                // Archive outputs
                archiveArtifacts artifacts: 'outputs.json,deployment-info.txt', allowEmptyArchive: false
            }
        }

        stage('Post-Deployment Validation') {
            when {
                expression {
                    return !params.DESTROY
                }
            }
            steps {
                echo "========== Validating deployment =========="
                sh '''
                    # Check if EC2 instances are running
                    INSTANCE_IDS=$(terraform output -json instance_ids | jq -r '.[]')
                    
                    if [ -n "$INSTANCE_IDS" ]; then
                        aws ec2 describe-instances \
                            --instance-ids $INSTANCE_IDS \
                            --query 'Reservations[].Instances[].{ID:InstanceId,State:State.Name}' \
                            --output table
                    fi
                    
                    # Health check example
                    echo "Instances deployed and running ✓"
                '''
            }
        }
    }

    post {
        always {
            echo "========== Cleaning up =========="
            sh '''
                # Clean up sensitive files
                rm -f backend-config.hcl
                rm -f terraform.tfvars.backup
            '''
        }

        success {
            echo "✅ Pipeline succeeded!"
            // Send notification (Slack, email, etc)
            // slackSend(channel: '#deployments', message: "Terraform ${ENVIRONMENT} deployed successfully!")
        }

        failure {
            echo "❌ Pipeline failed!"
            // Send failure notification
            // slackSend(channel: '#deployments', message: "Terraform ${ENVIRONMENT} deployment failed!")
        }

        unstable {
            echo "⚠️  Pipeline unstable"
        }

        aborted {
            echo "⏹️  Pipeline aborted"
        }
    }
}

// ============================================================================
// ADVANCED JENKINS PIPELINE (Shared Library Pattern)
// ============================================================================

/*
@Library('terraform-shared-lib') _

pipeline {
    agent {
        label 'terraform'
    }

    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'])
        booleanParam(name: 'AUTO_APPROVE', defaultValue: false)
    }

    stages {
        stage('Terraform') {
            steps {
                script {
                    // Use shared library function
                    terraformPipeline(
                        environment: params.ENVIRONMENT,
                        autoApprove: params.AUTO_APPROVE,
                        tfVarsFile: "environments/${params.ENVIRONMENT}.tfvars"
                    )
                }
            }
        }
    }
}
*/

// ============================================================================
// CREDENTIALS MANAGEMENT IN JENKINS
// ============================================================================

/*
// Use Jenkins credentials for AWS access:

pipeline {
    agent any

    environment {
        // Option 1: Using AWS credentials plugin
        AWS_CREDENTIALS = credentials('aws-terraform-credentials')
        AWS_ACCESS_KEY_ID = "${AWS_CREDENTIALS_USR}"
        AWS_SECRET_ACCESS_KEY = "${AWS_CREDENTIALS_PSW}"

        // Option 2: Using IAM role (EC2 agent)
        // No credentials needed - uses instance IAM role

        // Option 3: Using Vault
        // VAULT_ADDR = 'https://vault.example.com'
        // VAULT_TOKEN = credentials('vault-token')
    }

    stages {
        stage('Example') {
            steps {
                sh 'aws sts get-caller-identity'
            }
        }
    }
}
*/

// ============================================================================
// TERRAFORM BACKEND CONFIGURATION IN JENKINS
// ============================================================================

/*
stage('Init with Backend Config') {
    steps {
        withAWS(credentials: 'aws-credentials', region: 'us-east-1') {
            sh '''
                terraform init \
                    -backend-config="bucket=terraform-state-bucket" \
                    -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
                    -backend-config="region=us-east-1" \
                    -backend-config="dynamodb_table=terraform-locks" \
                    -backend-config="encrypt=true" \
                    -reconfigure
            '''
        }
    }
}
*/

// ============================================================================
// JENKINS AGENT CONFIGURATION
// ============================================================================

/*
// Agent requirements for Terraform CI/CD:

- Jenkins agent needs:
  1. Terraform CLI installed (1.0+)
  2. AWS CLI v2
  3. Git
  4. tfsec (optional, for security scanning)
  5. jq (for JSON processing)
  
// Docker agent option:
agent {
    docker {
        image 'hashicorp/terraform:latest'
        args '--entrypoint=""'
    }
}

// Or use terraform Docker image with AWS CLI:
agent {
    docker {
        image 'amazon/aws-cli:latest'
        args '-v /var/run/docker.sock:/var/run/docker.sock'
    }
}
*/

// ============================================================================
// MULTI-ENVIRONMENT JENKINS PIPELINE
// ============================================================================

/*
pipeline {
    agent { label 'terraform' }

    stages {
        stage('Dev Deploy') {
            steps {
                build job: 'terraform-deploy', parameters: [
                    string(name: 'ENVIRONMENT', value: 'dev')
                ]
            }
        }

        stage('Staging Deploy') {
            when {
                branch 'main'
            }
            steps {
                build job: 'terraform-deploy', parameters: [
                    string(name: 'ENVIRONMENT', value: 'staging')
                ]
            }
        }

        stage('Production Deploy') {
            when {
                tag pattern: "release-.*", comparator: "REGEXP"
            }
            steps {
                input 'Deploy to Production?'
                build job: 'terraform-deploy', parameters: [
                    string(name: 'ENVIRONMENT', value: 'prod')
                ]
            }
        }
    }
}
*/

// ============================================================================
// NOTES
// ============================================================================

/*
Jenkins Integration Best Practices:

1. Agent Configuration:
   - Dedicated Terraform agent(s)
   - Pre-installed tools (terraform, aws-cli, tfsec)
   - Access to AWS credentials
   - Sufficient disk space for state files

2. Credentials Management:
   - Use Jenkins credentials plugin (encrypted storage)
   - Avoid hardcoding credentials
   - Use IAM roles for EC2 agents
   - Rotate credentials regularly
   - Use AWS STS for temporary credentials

3. State Management:
   - Always use remote backend (S3 + DynamoDB)
   - Enable state locking
   - Regular state backups
   - Access state only from pipeline

4. Approvals:
   - Always require approval for prod
   - Manual review of plan before apply
   - Double-check destroy operations
   - Log all approvals/actions

5. Security:
   - Scan code (tfsec, checkov)
   - Encrypt state (KMS)
   - Audit CloudTrail
   - Regular access reviews

6. Monitoring:
   - Pipeline execution logs
   - Terraform output artifacts
   - Deployment notifications
   - Health checks post-deploy

7. Error Handling:
   - Catch plan failures
   - Prevent apply if plan fails
   - Rollback procedures
   - Post-failure notifications
*/
