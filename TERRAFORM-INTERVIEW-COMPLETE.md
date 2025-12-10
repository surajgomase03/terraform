# Terraform Complete Interview Preparation Guide

**Last Updated:** December 11, 2025  
**Coverage:** All topics from Basics to Advanced CI/CD  
**Purpose:** One file with everything you need for Terraform interviews

---

## Table of Contents
1. [Terraform Basics](#terraform-basics)
2. [HCL & Configuration](#hcl--configuration)
3. [Providers & Resources](#providers--resources)
4. [Variables & Outputs](#variables--outputs)
5. [Data Sources](#data-sources)
6. [Modules](#modules)
7. [State Management](#state-management)
8. [Workspaces](#workspaces)
9. [Count & For_each](#count--foreach)
10. [Import & Drift Detection](#import--drift-detection)
11. [Provisioners](#provisioners)
12. [Functions & Expressions](#functions--expressions)
13. [Security Best Practices](#security-best-practices)
14. [CI/CD Integration](#cicd-integration)
15. [Advanced Topics](#advanced-topics)

---

## Terraform Basics

### What is Terraform?
Terraform is a tool to write, plan, and create infrastructure as code (IaC). You write code that describes what infrastructure you want, and Terraform creates it.

### Why Use Terraform?
- Version control your infrastructure
- Automate deployment
- Easy to replicate environments
- Easier to manage and update
- Disaster recovery

### Terraform vs Other Tools
| Tool | Use Case |
|------|----------|
| **Terraform** | Multi-cloud, infrastructure code |
| **CloudFormation** | AWS only, JSON/YAML |
| **Ansible** | Configuration management |
| **Docker** | Application containers |

### Terraform Workflow
```
1. Write code (main.tf)
2. terraform init - download providers
3. terraform plan - preview changes
4. terraform apply - create resources
5. terraform destroy - delete resources
```

### Key Terms
- **Provider:** Connection to cloud (AWS, Azure, GCP)
- **Resource:** Infrastructure object (EC2, S3, VPC)
- **Data Source:** Read-only lookup of existing resources
- **Module:** Reusable package of Terraform code
- **State File:** Records what Terraform created
- **Variable:** Input values for flexibility
- **Output:** Show results after apply

---

## HCL & Configuration

### HCL Basics
HCL (HashiCorp Configuration Language) is how you write Terraform code.

```hcl
# Block structure
resource "resource_type" "name" {
  key = "value"
}

# Example
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

### File Organization
```
project/
├── main.tf          # Resources
├── variables.tf     # Input variables
├── outputs.tf       # Output values
├── provider.tf      # Provider config
├── terraform.tfvars # Variable values
└── modules/         # Reusable modules
```

### Comments
```hcl
# Single line comment
# Another comment

/*
Multi-line
comment
*/
```

---

## Providers & Resources

### What is a Provider?
A provider is a plugin that lets Terraform talk to a cloud service (AWS, Azure, etc).

### Provider Configuration
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}
```

### Resource Basics
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "my-server"
  }
}
```

### Resource Meta-Arguments
```hcl
# depends_on - explicit dependencies
depends_on = [aws_security_group.main]

# count - create multiple
count = 3

# for_each - create with map keys
for_each = var.servers

# lifecycle - control creation/deletion
lifecycle {
  create_before_destroy = true
  prevent_destroy       = true
}
```

---

## Variables & Outputs

### Variables
Variables let you pass values into Terraform code.

```hcl
variable "instance_count" {
  type        = number
  default     = 2
  description = "Number of instances"
}
```

### Variable Types
```
string    - "hello"
number    - 42
bool      - true
list      - ["a", "b", "c"]
map       - { web = "t2.micro" }
object    - { name = "john", age = 30 }
set       - unique items
```

### Pass Variables
```bash
# Command line
terraform apply -var='instance_count=3'

# From file
terraform apply -var-file='prod.tfvars'

# Environment variable
export TF_VAR_instance_count=3
terraform apply
```

### Outputs
Outputs show you important values after apply.

```hcl
output "instance_id" {
  value = aws_instance.web.id
}

output "instance_ip" {
  value       = aws_instance.web.public_ip
  sensitive   = true  # Hide from logs
  description = "Server IP address"
}
```

### Get Output Values
```bash
terraform output                    # Show all
terraform output instance_id        # Show specific
terraform output -json              # JSON format
```

---

## Data Sources

### What are Data Sources?
Data sources read existing resources - they don't create anything.

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Use the data
resource "aws_instance" "web" {
  ami = data.aws_ami.ubuntu.id
}
```

### Common Data Sources
```hcl
# Get latest AMI
data "aws_ami" "ubuntu" { ... }

# Get existing VPC
data "aws_vpc" "main" { ... }

# Get secrets
data "aws_ssm_parameter" "secret" { ... }

# Get subnets
data "aws_subnets" "private" { ... }
```

### Data vs Resource
| Data | Resource |
|------|----------|
| Reads existing | Creates new |
| Read-only | Can modify |
| No state | Saved in state |

---

## Modules

### What are Modules?
Modules are reusable packages of Terraform code.

```hcl
# Use a module
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = "10.0.0.0/16"
}
```

### Module Structure
```
modules/
└── vpc/
    ├── main.tf       # Resources
    ├── variables.tf  # Inputs
    ├── outputs.tf    # Outputs
    └── README.md     # Documentation
```

### Module Example
```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block = var.cidr_block
}

# modules/vpc/variables.tf
variable "cidr_block" {
  type = string
}

# modules/vpc/outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}
```

### Use Module
```hcl
module "vpc" {
  source = "./modules/vpc"
  
  cidr_block = "10.0.0.0/16"
}

# Reference output
resource "aws_subnet" "main" {
  vpc_id = module.vpc.vpc_id
}
```

### Module Best Practices
- Keep modules small and focused
- Document inputs and outputs
- Version your modules
- Reuse across projects
- Test modules separately

---

## State Management

### What is State?
State file (`terraform.tfstate`) records all resources Terraform created.

```json
{
  "resources": [
    {
      "type": "aws_instance",
      "name": "web",
      "instances": [
        {
          "attributes": {
            "id": "i-1234567890abcdef0"
          }
        }
      ]
    }
  ]
}
```

### State File Locations
```
Local: terraform.tfstate
Remote: S3, Azure Storage, Terraform Cloud
```

### Remote State
Store state in a safe place for teams.

```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}
```

### State Commands
```bash
terraform state list               # Show all resources
terraform state show aws_instance.web  # Show specific
terraform state mv old.name new.name   # Rename resource
terraform state rm aws_instance.web    # Remove from state
```

### State Best Practices
- Never commit state to Git
- Use remote state for teams
- Enable state locking (DynamoDB)
- Backup state regularly
- Encrypt state files
- Limit access to state

### State Locking
Prevents two people from changing at the same time.

```hcl
terraform {
  backend "s3" {
    ...
    dynamodb_table = "terraform-locks"
  }
}
```

---

## Workspaces

### What are Workspaces?
Workspaces let you manage multiple environments with the same code.

```bash
# List workspaces
terraform workspace list

# Create workspace
terraform workspace new dev

# Switch workspace
terraform workspace select prod

# Current workspace
terraform workspace show
```

### Workspace Example
```bash
# Deploy to dev
terraform workspace select dev || terraform workspace new dev
terraform apply -var-file=dev.tfvars

# Deploy to prod
terraform workspace select prod
terraform apply -var-file=prod.tfvars
```

### Workspace vs Directories
| Workspace | Separate Directories |
|-----------|-----------------|
| Same code, different state | Different code, different state |
| Easy for similar environments | Better for different infrastructure |
| Shared variables | Separate var files |

### Use Workspace Name in Code
```hcl
resource "aws_instance" "web" {
  tags = {
    Environment = terraform.workspace
  }
}
```

---

## Count & For_each

### Count Meta-Argument
Creates multiple identical resources.

```hcl
variable "instance_count" { default = 2 }

resource "aws_instance" "web" {
  count         = var.instance_count
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "web-${count.index}"
  }
}

# Reference
# aws_instance.web[0].id
# aws_instance.web[1].id
```

### For_each Meta-Argument
Creates resources with named keys (more stable).

```hcl
locals {
  servers = {
    web = { type = "t2.micro" }
    db  = { type = "t2.small" }
  }
}

resource "aws_instance" "server" {
  for_each      = local.servers
  instance_type = each.value.type

  tags = {
    Name = each.key
  }
}

# Reference
# aws_instance.server["web"].id
# aws_instance.server["db"].id
```

### Count vs For_each
| Count | For_each |
|-------|----------|
| Use numbers | Use keys |
| Less stable | More stable |
| Good for simple lists | Good for named resources |
| Reorder = recreate | Rename = recreate |

### Inside Loop
```hcl
# With count
count.index      # 0, 1, 2
count.value      # value if available

# With for_each
each.key         # "web", "db"
each.value       # { type = "t2.micro" }
```

---

## Import & Drift Detection

### Terraform Import
Add existing resources to Terraform management.

```bash
# Add resource to code
resource "aws_instance" "web" {
}

# Import existing resource
terraform import aws_instance.web i-1234567890abcdef0

# Update code to match
terraform plan  # Should show no changes
```

### Import Steps
1. Write resource block (empty)
2. Run `terraform import`
3. Update code to match actual resource
4. Run `terraform plan` to verify

### Drift Detection
Detects when infrastructure changes outside Terraform.

```bash
# Check for drift
terraform plan

# Shows what's different
# ~ means changed
# + means added
# - means removed
```

### Resolve Drift
```bash
# Option 1: Update code to match
# Edit main.tf

# Option 2: Refresh state
terraform refresh

# Option 3: Replace resource
terraform apply -replace=aws_instance.web
```

---

## Provisioners

### Local-exec
Run commands on your machine.

```hcl
resource "aws_instance" "web" {
  ami = "ami-0c55b159cbfafe1f0"

  provisioner "local-exec" {
    command = "echo ${self.public_ip} > server_ip.txt"
  }
}
```

### Remote-exec
Run commands on the created resource.

```hcl
resource "aws_instance" "web" {
  ami = "ami-0c55b159cbfafe1f0"

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt install nginx -y"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }
}
```

### File Provisioner
Copy files to resource.

```hcl
provisioner "file" {
  source      = "local/path/app.conf"
  destination = "/tmp/app.conf"

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/id_rsa")
    host        = self.public_ip
  }
}
```

### When to Use Provisioners
- Last resort option
- Prefer user_data for EC2
- Prefer cloud-init or configuration management
- Use for monitoring/logging setup only

---

## Functions & Expressions

### Conditional Expression
```hcl
# if-then-else
resource "aws_instance" "web" {
  instance_type = var.environment == "prod" ? "t3.large" : "t2.micro"
}
```

### String Functions
```hcl
upper("hello")              # HELLO
lower("HELLO")              # hello
length("hello")             # 5
split(",", "a,b,c")        # ["a", "b", "c"]
join(",", ["a", "b"])      # "a,b"
replace("hello", "l", "L")  # heLLo
```

### List Functions
```hcl
length(var.servers)             # Count items
concat(list1, list2)            # Combine lists
contains(list, "item")          # Check if exists
index(list, "item")             # Find position
reverse(list)                   # Reverse order
```

### Map Functions
```hcl
keys(map)                       # Get keys
values(map)                     # Get values
merge(map1, map2)              # Combine maps
```

### Type Functions
```hcl
tostring(123)                   # Convert to string
tonumber("123")                 # Convert to number
tolist([1, 2])                  # Convert to list
tomap({ a = 1 })               # Convert to map
```

---

## Security Best Practices

### Secure Variables
```hcl
variable "db_password" {
  type      = string
  sensitive = true
}

output "db_endpoint" {
  value     = aws_db_instance.main.endpoint
  sensitive = true
}
```

### Avoid Secrets in Code
```bash
# BAD - Don't do this
provider "aws" {
  access_key = "AKIAIOSFODNN7EXAMPLE"
  secret_key = "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
}

# GOOD - Use environment variables
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
terraform apply
```

### Use AWS IAM Roles
```hcl
provider "aws" {
  # Automatically uses EC2 instance role
  region = "us-east-1"
}
```

### Encrypt State
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    encrypt        = true  # Enable encryption
    dynamodb_table = "terraform-locks"
  }
}
```

### Validation
```hcl
variable "instance_type" {
  type = string

  validation {
    condition     = contains(["t2.micro", "t2.small"], var.instance_type)
    error_message = "Must be t2.micro or t2.small"
  }
}
```

### Security Scanning
```bash
# tfsec - Security scanner
tfsec .

# Checkov - Policy as code
checkov -d .

# Trivy - Vulnerability scanner
trivy config .
```

---

## CI/CD Integration

### Jenkins Pipeline
```groovy
pipeline {
  agent any

  stages {
    stage('Terraform Init') {
      steps {
        sh 'terraform init'
      }
    }

    stage('Terraform Plan') {
      steps {
        sh 'terraform plan -out=tfplan'
      }
    }

    stage('Approve') {
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

### GitLab CI/CD
```yaml
stages:
  - plan
  - apply

plan:
  stage: plan
  script:
    - terraform init
    - terraform plan -out=tfplan

apply:
  stage: apply
  script:
    - terraform apply -auto-approve tfplan
  when: manual
```

### GitHub Actions
```yaml
name: Terraform

on: [push]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: hashicorp/setup-terraform@v1
      - run: terraform init
      - run: terraform plan
      - run: terraform apply -auto-approve
```

### Best Practices
- Always run `plan` before `apply`
- Require approval for production
- Store state remotely
- Encrypt sensitive variables
- Use CI/CD for consistency
- Test in dev before prod

---

## Advanced Topics

### Terraform Cloud
Managed Terraform service.

```hcl
terraform {
  cloud {
    organization = "my-org"

    workspaces {
      name = "production"
    }
  }
}
```

### Multi-Region Deployment
```hcl
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "eu-west-1"
  region = "eu-west-1"
}

resource "aws_instance" "us" {
  provider      = aws.us-east-1
  ami           = "ami-us"
  instance_type = "t2.micro"
}

resource "aws_instance" "eu" {
  provider      = aws.eu-west-1
  ami           = "ami-eu"
  instance_type = "t2.micro"
}
```

### Dynamic Blocks
```hcl
resource "aws_security_group" "main" {
  name = "main"

  dynamic "ingress" {
    for_each = var.ports
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}
```

### Locals
```hcl
locals {
  instance_type = var.environment == "prod" ? "t3.large" : "t2.micro"
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_instance" "web" {
  instance_type = local.instance_type
  tags          = local.common_tags
}
```

### Splat Syntax
```hcl
# Get all instance IDs
instance_ids = aws_instance.web[*].id

# Combine outputs
output "all_ips" {
  value = aws_instance.web[*].public_ip
}
```

---

## Common Interview Questions

### Q1: What is the difference between state and configuration?
**A:** Configuration (.tf files) describes what you want. State file records what Terraform actually created.

### Q2: How do you handle sensitive data?
**A:** Use `sensitive = true`, environment variables, or AWS Secrets Manager. Never commit secrets to Git.

### Q3: What causes state drift?
**A:** Someone changes infrastructure manually outside Terraform. Use `terraform plan` to detect it.

### Q4: When should you use modules?
**A:** When you have reusable infrastructure that will be used in multiple projects.

### Q5: Count vs For_each - when to use each?
**A:** Use count for simple numbering, for_each for named resources (more stable when adding/removing).

### Q6: How do you manage multiple environments?
**A:** Use workspaces for small differences, separate directories for large differences.

### Q7: What is the Terraform workflow?
**A:** Init → Plan → Apply. Always plan before apply.

### Q8: How do you ensure team collaboration?
**A:** Use remote state (S3, Terraform Cloud), enable state locking, use version control.

### Q9: How do you destroy resources?
**A:** `terraform destroy` deletes all resources. For specific: `terraform destroy -target=resource.name`

### Q10: What is a provisioner and when to use it?
**A:** Provisioner runs code on resource creation. Last resort - prefer user_data or cloud-init.

---

## Quick Commands Cheat Sheet

```bash
# Initialization
terraform init                          # Initialize Terraform

# Planning
terraform plan                          # Show what will change
terraform plan -out=tfplan              # Save plan
terraform plan -var-file=prod.tfvars    # Use var file

# Applying
terraform apply                         # Create/update resources
terraform apply tfplan                  # Apply saved plan
terraform apply -auto-approve           # Skip approval prompt

# Destroying
terraform destroy                       # Delete all resources
terraform destroy -target=resource      # Delete specific resource

# State Management
terraform state list                    # List all resources
terraform state show resource_name      # Show specific resource
terraform state mv old new              # Rename resource
terraform state rm resource_name        # Remove from state

# Validation & Formatting
terraform validate                      # Check syntax
terraform fmt                           # Format files
terraform fmt -recursive                # Format all files

# Outputs & Info
terraform output                        # Show outputs
terraform output -json                  # JSON format
terraform show                          # Show state
terraform refresh                       # Update state

# Workspaces
terraform workspace list                # List workspaces
terraform workspace new dev             # Create workspace
terraform workspace select prod         # Switch workspace
terraform workspace show                # Current workspace

# Debugging
terraform console                       # Interactive console
terraform graph                         # Show dependency graph
terraform import resource_type id       # Import resource
```

---

## File Structure Template

```
terraform/
├── main.tf                  # Main resources
├── variables.tf             # Variable definitions
├── outputs.tf               # Output definitions
├── provider.tf              # Provider configuration
├── terraform.tfvars         # Variable values (local)
├── dev.tfvars               # Dev environment
├── prod.tfvars              # Prod environment
├── .gitignore               # Ignore files
├── README.md                # Documentation
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── outputs.tf
    │   └── README.md
    ├── ec2/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── rds/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

## .gitignore Template

```
# Local .terraform directories
**/.terraform/*

# .tfstate files
*.tfstate
*.tfstate.*

# Crash log files
crash.log
crash.*.log

# Exclude all .tfvars files (with passwords)
*.tfvars
*.tfvars.json

# Ignore override files
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
```

---

## Resources for Further Learning

1. **Official Terraform Docs:** https://www.terraform.io/docs
2. **AWS Provider Docs:** https://registry.terraform.io/providers/hashicorp/aws
3. **Terraform Best Practices:** https://www.terraform.io/docs/cloud/guides/recommended-practices
4. **Terraform Registry:** https://registry.terraform.io/
5. **HashiCorp Learning:** https://learn.hashicorp.com/terraform

---

## Interview Tips

✅ **Do:**
- Always run `terraform plan` before `apply`
- Use remote state for teams
- Document your modules
- Test in dev before prod
- Use version control
- Enable state locking
- Keep modules focused and small
- Ask clarifying questions

❌ **Don't:**
- Commit state files to Git
- Hardcode credentials
- Skip the plan step
- Use provisioners when possible
- Run destroy without confirmation
- Mix environments in one state
- Ignore security warnings

---

**Good luck with your Terraform interview!** 🚀

This guide covers all major topics from basics to advanced. Review sections that are weak, practice with code examples, and understand the "why" behind each concept.

