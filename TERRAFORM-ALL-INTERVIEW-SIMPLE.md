# Terraform Complete Interview Guide - Simple Language

**Last Updated:** February 4, 2026  
**Purpose:** All Terraform topics explained in SIMPLE words for interviews  
**Coverage:** Beginner to Advanced + Interview Q&A

---

## Table of Contents
1. [Terraform Basics](#basics)
2. [Installation & Setup](#setup)
3. [Providers & Resources](#providers)
4. [Variables & Outputs](#variables)
5. [State Management](#state)
6. [Modules](#modules)
7. [Functions & Expressions](#functions)
8. [Count & For_each](#count)
9. [Data Sources](#data)
10. [Conditionals & Loops](#conditionals)
11. [Provisioners](#provisioners)
12. [Workspaces](#workspaces)
13. [Import & Drift](#import)
14. [Security & Secrets](#security)
15. [Backends](#backends)
16. [Troubleshooting](#troubleshooting)
17. [Best Practices](#practices)
18. [CI/CD Integration](#cicd)

---

# BASICS

## Q: What is Terraform?

**Simple Answer:**
Terraform is a tool to create, update, and delete cloud resources (like servers, databases, networks) by writing code instead of clicking buttons in the cloud console.

**Why it's useful:**
- Write once, reuse many times
- Keep track of all changes (version control)
- Automated deployment
- No manual mistakes
- Easy to destroy and recreate

**Example:**
Instead of:
1. Open AWS console
2. Click EC2
3. Click Launch Instance
4. Select AMI, instance type, security group... (20 steps)

You write:
```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"
}
```

Then run: `terraform apply`

---

## Q: What's the difference between Terraform and other IaC tools?

| Tool | Use Case | Best For |
|------|----------|----------|
| **Terraform** | Multi-cloud IaC | AWS, Azure, GCP together |
| **CloudFormation** | AWS only | AWS-only projects |
| **Ansible** | Configuration management | Install software on existing servers |
| **Docker** | Application packaging | Running apps in containers |
| **Kubernetes** | Container orchestration | Managing containers at scale |
| **ARM Templates** | Azure only | Azure-only projects |

**Simple rule:** Use Terraform to CREATE infrastructure, use Ansible to CONFIGURE it.

---

## Q: What are the main benefits of IaC (Infrastructure as Code)?

**Benefits:**
1. **Repeatability:** Create same infrastructure anywhere, anytime
2. **Version Control:** See who changed what and when
3. **Automation:** No manual clicking, faster deployment
4. **Documentation:** Code IS documentation
5. **Cost Control:** See exactly what you're creating
6. **Disaster Recovery:** Recreate everything in minutes
7. **Consistency:** No "it works on my machine" problems
8. **Rollback:** Go back to previous version easily

---

## Q: What's the Terraform Workflow?

**The 4 Steps:**

```
1. WRITE (.tf files)
   ↓
2. INIT (terraform init)
   - Download provider plugins
   ↓
3. PLAN (terraform plan)
   - Preview what will happen
   ↓
4. APPLY (terraform apply)
   - Actually create resources
```

**Optional:**
- `terraform destroy` - Delete everything

---

## Q: What files does Terraform create?

**Important files:**

1. **terraform.tf/.tf files** - Your code
2. **.terraform/plugins** - Provider plugins (auto-created)
3. **terraform.tfstate** - What's currently deployed (IMPORTANT!)
4. **terraform.tfstate.backup** - Backup of state
5. **.terraform.lock.hcl** - Provider version lock
6. **.gitignore** - Things not to commit

**What to commit to Git:**
```
✓ main.tf
✓ variables.tf
✓ outputs.tf
✓ .terraform.lock.hcl
✗ .terraform/ (folder)
✗ terraform.tfstate
✗ terraform.tfstate.backup
✗ .env files
```

---

# SETUP

## Q: How do I install Terraform?

**Windows:**
1. Download from terraform.io
2. Extract to a folder
3. Add folder to PATH
4. Verify: `terraform version`

**Mac:**
```bash
brew install terraform
terraform version
```

**Linux:**
```bash
# Download
wget https://releases.hashicorp.com/terraform/...
unzip terraform_*.zip
sudo mv terraform /usr/local/bin/
terraform version
```

---

## Q: How do I connect Terraform to AWS?

**Method 1: Environment Variables**
```bash
export AWS_ACCESS_KEY_ID="your-key"
export AWS_SECRET_ACCESS_KEY="your-secret"
export AWS_DEFAULT_REGION="us-east-1"
```

**Method 2: Credentials file**
```
~/.aws/credentials
[default]
aws_access_key_id = YOUR_KEY
aws_secret_access_key = YOUR_SECRET
```

**Method 3: Terraform code**
```hcl
provider "aws" {
  region     = "us-east-1"
  access_key = "your-key"
  secret_key = "your-secret"
}
```

**Best Practice:** Use environment variables or AWS credentials file. Never hardcode keys!

---

# PROVIDERS

## Q: What is a Provider?

**Simple Answer:** A provider is a plugin that lets Terraform talk to a cloud service.

**Providers Available:**
- AWS
- Azure
- GCP
- Kubernetes
- Docker
- GitHub
- Datadog
- And 100+ more...

**Basic Usage:**
```hcl
provider "aws" {
  region = "us-east-1"
}

provider "azure" {
  region = "eastus"
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}
```

---

## Q: What is a Resource?

**Simple Answer:** A resource is ONE piece of infrastructure (like a server, database, network).

**Syntax:**
```hcl
resource "aws_instance" "my_server" {
  ami           = "ami-12345"
  instance_type = "t2.micro"
  tags = {
    Name = "My Server"
  }
}
```

Breaking it down:
- `resource` - This is a resource
- `"aws_instance"` - Type (from AWS provider)
- `"my_server"` - Name (you choose this)
- Everything inside = configuration

**Accessing it later:**
```hcl
aws_instance.my_server.id
aws_instance.my_server.public_ip
```

---

## Q: What's the difference between Provider and Resource?

**Provider:**
- Helps you CONNECT to a cloud
- You need 1 provider to create multiple resources

**Resource:**
- One actual thing created in the cloud
- Multiple resources use 1 provider

**Example:**
```hcl
# 1 Provider (the plugin)
provider "aws" {
  region = "us-east-1"
}

# 3 Resources (actual things created)
resource "aws_instance" "web" {
  ami = "ami-12345"
}

resource "aws_s3_bucket" "data" {
  bucket = "my-bucket"
}

resource "aws_security_group" "web_sg" {
  name = "web-sg"
}
```

---

# VARIABLES

## Q: What are Variables?

**Simple Answer:** Variables let you pass different values to your code, instead of hardcoding everything.

**Why use variables?**
- Reuse same code in different environments (dev, staging, prod)
- Easy to change values without editing code
- Make code cleaner and more readable

**Example:**
```hcl
variable "instance_type" {
  description = "What size server?"
  type        = string
  default     = "t2.micro"
}

resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = var.instance_type  # Use the variable
}
```

**Use it:**
```bash
terraform apply -var="instance_type=t2.small"
```

---

## Q: What are the different types of Variables?

**Types:**

1. **String:** Text
```hcl
variable "name" {
  type = string
  default = "john"
}
```

2. **Number:** Integer or decimal
```hcl
variable "count" {
  type = number
  default = 5
}
```

3. **Boolean:** True or False
```hcl
variable "enabled" {
  type = bool
  default = true
}
```

4. **List:** Multiple items of same type
```hcl
variable "availability_zones" {
  type = list(string)
  default = ["us-east-1a", "us-east-1b"]
}
# Access: var.availability_zones[0]
```

5. **Map:** Key-value pairs
```hcl
variable "tags" {
  type = map(string)
  default = {
    Environment = "prod"
    Owner       = "john"
  }
}
# Access: var.tags["Environment"]
```

6. **Object:** Complex structure
```hcl
variable "server" {
  type = object({
    name  = string
    size  = string
    count = number
  })
}
```

7. **Tuple:** Fixed list with different types
```hcl
variable "info" {
  type = tuple([string, number, bool])
}
```

---

## Q: How do I provide Variable values?

**Method 1: Command line**
```bash
terraform apply -var="instance_type=t2.small"
```

**Method 2: terraform.tfvars file**
```hcl
instance_type = "t2.small"
name          = "prod-server"
enabled       = true
```

**Method 3: Environment variables**
```bash
export TF_VAR_instance_type="t2.small"
terraform apply
```

**Method 4: Default in code**
```hcl
variable "instance_type" {
  type    = string
  default = "t2.small"  # This is the default
}
```

**Priority (which wins?):**
1. Command line (`-var`)
2. Environment variables (`TF_VAR_`)
3. terraform.tfvars file
4. Default value in code
5. If none, ask user interactively

---

## Q: What are Outputs?

**Simple Answer:** Outputs are like "return values" - they show you important information after resources are created.

**Why use outputs?**
- Get IP addresses after server creation
- Get database endpoint
- Show other module what was created
- Easy reference

**Example:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345"
  instance_type = "t2.micro"
}

output "server_ip" {
  value = aws_instance.web.public_ip
  description = "Public IP of the server"
}
```

**Result:**
```
Outputs:
server_ip = "54.123.45.67"
```

---

## Q: What is Variable Validation?

**Simple Answer:** Validate = check if variable value is correct before using it.

**Example:**
```hcl
variable "instance_type" {
  type = string
  
  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium"], var.instance_type)
    error_message = "Only t2.micro, t2.small, or t2.medium allowed!"
  }
}
```

**If someone tries:**
```bash
terraform apply -var="instance_type=x1.massive"
# ERROR: Only t2.micro, t2.small, or t2.medium allowed!
```

---

# STATE

## Q: What is State File?

**Simple Answer:** State file is a database that keeps track of what Terraform created.

**Why important?**
- Terraform compares desired state (your code) with current state (state file)
- Knows what to create, update, or destroy
- Without state file, Terraform doesn't know what it created

**Example:**
```
terraform.tfstate:
{
  "aws_instance.web": {
    "id": "i-1234567890abcdef0",
    "public_ip": "54.123.45.67",
    ...
  }
}
```

**State = Truth:** If state says resource exists, Terraform believes it.

---

## Q: Local vs Remote State - What's the difference?

**Local State:**
```
Stored: Your computer (terraform.tfstate file)
Good for: Learning, small projects, solo work
Bad for: Teams, production, collaboration
Risks: Easily deleted, not backed up
```

**Remote State:**
```
Stored: S3, Terraform Cloud, etc.
Good for: Teams, production, collaboration
Bad for: More setup needed
Benefits: Backup, state locking, team access
```

**Example Local:**
```hcl
# Default - no configuration needed
terraform apply
# Creates: terraform.tfstate (on your machine)
```

**Example Remote (S3):**
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

## Q: What is State Locking?

**Simple Answer:** Prevents two people from making changes at the same time.

**Without locking:**
```
Person A: terraform apply (creating server)
Person B: terraform apply (at same time)
Result: CONFLICT! State corrupted!
```

**With locking:**
```
Person A: terraform apply (LOCKS state)
Person B: terraform apply (WAITS... locked)
Person A: Finishes (UNLOCKS state)
Person B: Now applies (LOCKS again)
```

**Locking backends:**
- DynamoDB (for S3)
- Terraform Cloud
- Consul
- PostgreSQL

**Example with DynamoDB:**
```hcl
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "terraform.tfstate"
    dynamodb_table = "terraform-lock"  # State locking
    region         = "us-east-1"
  }
}
```

---

## Q: What is Terraform Refresh?

**Simple Answer:** Check if real resources still match the state file.

**When to use:**
- Manual changes made in AWS console
- Resources deleted outside Terraform
- Check current status

**Command:**
```bash
terraform refresh
# Updates state file with current reality
```

**Example:**
```
State says: Server is running
Reality: Server was stopped manually
After refresh: State is updated to show stopped
```

---

## Q: What is State Encryption?

**Simple Answer:** Encrypt state file so no one can read your secrets.

**Why?**
- State file contains passwords, API keys, etc.
- Anyone with access can read secrets

**How?**
```hcl
terraform {
  backend "s3" {
    bucket              = "my-bucket"
    key                 = "terraform.tfstate"
    encrypt             = true  # Enable encryption
    dynamodb_table      = "terraform-lock"
    region              = "us-east-1"
  }
}
```

**Also:**
- Enable S3 bucket encryption
- Enable versioning on S3
- Restrict who can access S3 bucket

---

# MODULES

## Q: What is a Module?

**Simple Answer:** A module is reusable Terraform code - like a function or library.

**Why use modules?**
- Don't repeat code
- Organize code better
- Share code with team
- Use community modules

**Structure:**
```
my-project/
├── main.tf (uses modules)
├── modules/
│   └── vpc/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── provider.tf
```

**Simple Example:**

**modules/ec2/main.tf**
```hcl
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type
  tags = {
    Name = var.server_name
  }
}
```

**modules/ec2/variables.tf**
```hcl
variable "ami_id" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "server_name" {
  type = string
}
```

**modules/ec2/outputs.tf**
```hcl
output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}
```

**main.tf (use the module)**
```hcl
module "web_server" {
  source = "./modules/ec2"
  
  ami_id        = "ami-12345"
  instance_type = "t2.small"
  server_name   = "production-web"
}

# Access outputs:
output "server_id" {
  value = module.web_server.instance_id
}
```

---

## Q: Local vs Public Registry Modules - What's the difference?

**Local Modules:**
```
Location: In your project folder (./modules/vpc)
Updates: You maintain
Sharing: Via Git only
Best for: Private reusable code
Control: Full control
```

**Public Registry:**
```
Location: terraform.io registry
Updates: Maintained by community/HashiCorp
Sharing: Published for everyone
Best for: Common infrastructure (VPC, K8s, etc)
Control: Limited - use as-is
```

**Using local module:**
```hcl
module "my_vpc" {
  source = "./modules/vpc"
}
```

**Using public module:**
```hcl
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "3.0"
}
```

---

## Q: What are Child Modules?

**Simple Answer:** Modules that use other modules (nested modules).

**Example:**

**modules/vpc/main.tf**
```hcl
module "security_group" {
  source = "./security_group"  # Uses child module
}

resource "aws_vpc" "main" {
  cidr_block = var.cidr
}
```

**Structure:**
```
modules/
├── vpc/
│   ├── main.tf (uses security_group)
│   └── security_group/  (child module)
│       └── main.tf
```

---

## Q: How do I pass data between Modules?

**Example:**

**modules/vpc/outputs.tf**
```hcl
output "vpc_id" {
  value = aws_vpc.main.id
}
```

**main.tf**
```hcl
module "vpc" {
  source = "./modules/vpc"
}

module "ec2" {
  source = "./modules/ec2"
  vpc_id = module.vpc.vpc_id  # Pass VPC ID to EC2 module
}
```

---

## Q: What is Module Composition?

**Simple Answer:** Combining multiple modules to create a complete infrastructure.

**Example:**

**main.tf**
```hcl
# Create networking layer
module "networking" {
  source = "./modules/vpc"
}

# Create database layer
module "database" {
  source = "./modules/rds"
  vpc_id = module.networking.vpc_id
}

# Create compute layer
module "compute" {
  source = "./modules/ec2"
  vpc_id = module.networking.vpc_id
  db_endpoint = module.database.endpoint
}
```

**Output to user:**
```hcl
output "application_url" {
  value = "http://${module.compute.public_ip}"
}
```

---

# FUNCTIONS

## Q: What are Terraform Functions?

**Simple Answer:** Built-in functions to manipulate data.

**Common Functions:**

**String Functions:**
```hcl
# Length
length("hello")  # 5

# Upper/Lower
upper("hello")   # HELLO
lower("HELLO")   # hello

# Replace
replace("hello", "l", "x")  # hexxo

# Join
join(",", ["a", "b", "c"])  # a,b,c

# Split
split(",", "a,b,c")  # ["a", "b", "c"]
```

**Number Functions:**
```hcl
# Max/Min
max(1, 5, 3)  # 5
min(1, 5, 3)  # 1

# Sum
sum([1, 2, 3])  # 6

# Ceil/Floor
ceil(1.2)    # 2
floor(1.9)   # 1
```

**List Functions:**
```hcl
# Contains
contains(["a", "b", "c"], "b")  # true

# Index
index(["a", "b", "c"], "b")  # 1

# Concat
concat(["a"], ["b", "c"])  # ["a", "b", "c"]

# Reverse
reverse([1, 2, 3])  # [3, 2, 1]

# Sort
sort(["c", "a", "b"])  # ["a", "b", "c"]
```

**Map Functions:**
```hcl
# Keys
keys({a = 1, b = 2})  # [a, b]

# Values
values({a = 1, b = 2})  # [1, 2]

# Merge
merge({a = 1}, {b = 2})  # {a = 1, b = 2}
```

**Type Functions:**
```hcl
# Type
type("hello")  # string
type(123)      # number

# Convert types
tostring(123)  # "123"
tonumber("456")  # 456
tolist([1, 2])  # [1, 2]
tomap({a = 1})  # {a = 1}
```

---

## Q: What is String Interpolation?

**Simple Answer:** Putting variables inside strings.

**Syntax:**
```hcl
"${variable_or_expression}"
```

**Examples:**
```hcl
variable "name" {
  default = "john"
}

variable "age" {
  default = 30
}

# String interpolation
output "message" {
  value = "My name is ${var.name} and I am ${var.age} years old"
}

# Result: "My name is john and I am 30 years old"
```

**With resources:**
```hcl
resource "aws_instance" "web" {
  ami = "ami-12345"
}

resource "aws_security_group" "web_sg" {
  name = "sg-for-${aws_instance.web.id}"
}
```

---

# COUNT

## Q: What is Count?

**Simple Answer:** Create multiple identical resources without repeating code.

**Simple Example:**
```hcl
resource "aws_instance" "servers" {
  count         = 3  # Create 3 servers
  ami           = "ami-12345"
  instance_type = "t2.micro"
  tags = {
    Name = "server-${count.index}"  # server-0, server-1, server-2
  }
}
```

**Access them:**
```hcl
aws_instance.servers[0].id  # First server
aws_instance.servers[1].id  # Second server
aws_instance.servers[2].id  # Third server
```

**Example with Variable:**
```hcl
variable "server_count" {
  type    = number
  default = 3
}

resource "aws_instance" "servers" {
  count         = var.server_count
  ami           = "ami-12345"
  instance_type = "t2.micro"
}
```

**Count Index:**
```hcl
count.index       # 0, 1, 2, 3...
count.inputs      # The value passed
```

---

## Q: What is For_each?

**Simple Answer:** Like count, but better for different configurations.

**When to use for_each instead of count:**
- Resources have different configurations
- Using maps (key-value pairs)
- Removing from middle doesn't shift others

**Simple Example:**
```hcl
variable "servers" {
  type = map(string)
  default = {
    web  = "t2.micro"
    db   = "t2.small"
    cache = "t2.micro"
  }
}

resource "aws_instance" "servers" {
  for_each      = var.servers
  ami           = "ami-12345"
  instance_type = each.value  # t2.micro, t2.small, t2.micro
  tags = {
    Name = each.key  # web, db, cache
  }
}
```

**Access them:**
```hcl
aws_instance.servers["web"].id
aws_instance.servers["db"].id
aws_instance.servers["cache"].id
```

**For_each with Objects:**
```hcl
variable "instances" {
  type = map(object({
    type = string
    size = number
  }))
  default = {
    app = { type = "t2.micro", size = 20 }
    web = { type = "t2.small", size = 30 }
  }
}

resource "aws_instance" "servers" {
  for_each      = var.instances
  instance_type = each.value.type
  tags = {
    Name = each.key
    Size = each.value.size
  }
}
```

---

## Q: Count vs For_each - Which should I use?

**Count:**
- Simple situations (just need multiple copies)
- Indexed by number (0, 1, 2, 3)
- Removing middle item shifts others

**For_each:**
- Complex situations (different configs)
- Keyed by name/ID
- Removing item doesn't affect others
- Better for production

**Example Problem with Count:**

```hcl
# Version 1
resource "aws_instance" "servers" {
  count = 3
  # servers[0], servers[1], servers[2]
}

# Later you remove middle one
resource "aws_instance" "servers" {
  count = 2
  # servers[0], servers[1]
  # The old servers[2] gets RENAMED to servers[1]
  # Terraform destroys servers[1] and servers[2]!
}
```

**For_each avoids this:**
```hcl
# Version 1
resource "aws_instance" "servers" {
  for_each = {
    web = "t2.micro"
    db  = "t2.small"
    cache = "t2.micro"
  }
}

# Remove db from middle
resource "aws_instance" "servers" {
  for_each = {
    web = "t2.micro"
    cache = "t2.micro"  # Unchanged, still has same key
  }
}
# Only db is destroyed, web and cache unaffected!
```

**Best Practice:** Use for_each unless you really need count.

---

# DATA SOURCES

## Q: What are Data Sources?

**Simple Answer:** Data sources read information about existing resources without creating them.

**Why use data sources?**
- Get info about resources created outside Terraform
- Use existing AWS resources
- Look up latest AMI ID automatically
- Find available resources

**Common Data Sources:**

**Find AMI:**
```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  
  owners = ["099720109477"]  # Canonical
}

# Use it
resource "aws_instance" "web" {
  ami = data.aws_ami.ubuntu.id
}
```

**Find VPC:**
```hcl
data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "web" {
  vpc_id = data.aws_vpc.default.id
}
```

**Find existing subnet:**
```hcl
data "aws_subnet" "selected" {
  id = "subnet-12345"
}

output "availability_zone" {
  value = data.aws_subnet.selected.availability_zone
}
```

**Read from AWS Parameter Store:**
```hcl
data "aws_ssm_parameter" "db_password" {
  name = "/prod/db/password"
}

resource "aws_rds_instance" "main" {
  password = data.aws_ssm_parameter.db_password.value
}
```

---

## Q: Data Source vs Resource - What's the difference?

**Resource:**
- CREATES something new
- Has initial value set by you
- Creates infrastructure
- Terraform owns it

**Data Source:**
- READS existing information
- No creation happens
- Looks up existing resources
- Terraform doesn't own it

**Example:**
```hcl
# Resource - CREATES a server
resource "aws_instance" "web" {
  ami = "ami-12345"
}

# Data Source - READS info about existing server
data "aws_instance" "existing" {
  instance_id = "i-1234567"
}

# Use existing server's info
output "existing_ip" {
  value = data.aws_instance.existing.public_ip
}
```

---

# CONDITIONALS

## Q: What are Conditional Expressions?

**Simple Answer:** If-else logic in Terraform.

**Basic Syntax:**
```hcl
condition ? value_if_true : value_if_false
```

**Example:**
```hcl
variable "environment" {
  type    = string
  default = "prod"
}

resource "aws_instance" "web" {
  instance_type = var.environment == "prod" ? "t2.large" : "t2.micro"
  # Use t2.large for prod, t2.micro for others
}
```

**More complex:**
```hcl
variable "enable_monitoring" {
  type    = bool
  default = true
}

variable "monitoring_level" {
  type    = string
  default = "basic"
}

resource "aws_instance" "web" {
  monitoring = var.enable_monitoring ? true : false
  
  # Nested conditional
  tags = {
    MonitoringLevel = var.monitoring_level == "detailed" ? "5-minute" : "1-minute"
  }
}
```

---

## Q: What are Dynamic Blocks?

**Simple Answer:** Generate resource arguments dynamically based on a list.

**Problem without dynamic blocks:**
```hcl
# Without dynamic blocks - lots of repetition
resource "aws_security_group" "web" {
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}
```

**Solution with dynamic blocks:**
```hcl
variable "ingress_rules" {
  type = list(object({
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    { from_port = 80,  to_port = 80,  protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 443, to_port = 443, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"] },
    { from_port = 22,  to_port = 22,  protocol = "tcp", cidr_blocks = ["10.0.0.0/8"] }
  ]
}

resource "aws_security_group" "web" {
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }
}
```

**Cleaner!**

---

## Q: What are For Loops?

**Simple Answer:** Iterate over lists/maps to create or transform values.

**List comprehension:**
```hcl
variable "names" {
  default = ["john", "jane", "bob"]
}

# Create list of uppercase names
output "uppercase_names" {
  value = [for name in var.names : upper(name)]
  # ["JOHN", "JANE", "BOB"]
}
```

**Map comprehension:**
```hcl
variable "servers" {
  default = {
    web  = "t2.micro"
    db   = "t2.small"
    cache = "t2.micro"
  }
}

# Create new map with instances
output "server_instances" {
  value = {for name, size in var.servers : name => "i-${name}"}
  # { web = "i-web", db = "i-db", cache = "i-cache" }
}
```

**With condition:**
```hcl
variable "numbers" {
  default = [1, 2, 3, 4, 5]
}

# Get only even numbers
output "even_numbers" {
  value = [for n in var.numbers : n if n % 2 == 0]
  # [2, 4]
}
```

---

# PROVISIONERS

## Q: What are Provisioners?

**Simple Answer:** Run scripts or commands on resources when they're created or destroyed.

**Types:**
1. **local-exec** - Run script on YOUR machine
2. **remote-exec** - Run script ON the resource

**WARNING:** Use provisioners as LAST RESORT. Better to use user data or configuration management.

**Local-exec Example:**
```hcl
resource "aws_instance" "web" {
  ami = "ami-12345"
}

provisioner "local-exec" {
  command = "echo ${aws_instance.web.public_ip} > instance_ip.txt"
  # Runs: echo 54.123.45.67 > instance_ip.txt (on your machine)
}
```

**Remote-exec Example:**
```hcl
resource "aws_instance" "web" {
  ami           = "ami-12345"
  key_name      = aws_key_pair.deployer.key_name
  
  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y docker.io",
      "sudo systemctl start docker"
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

---

## Q: Provisioners vs User Data - When to use which?

**User Data:**
```
When: Use for initial setup
How: Script runs automatically when instance starts
Best for: Installing software, configuration
```

**Provisioners:**
```
When: Use for complex setup, copying files
How: Script runs during terraform apply
Best for: Testing, one-time tasks
```

**BEST PRACTICE:**
Use user data in most cases. Avoid provisioners.

**Why avoid provisioners?**
- If they fail, Terraform doesn't know
- Can't reapply easily
- Makes state unpredictable
- Slower than automation tools

---

# WORKSPACES

## Q: What are Workspaces?

**Simple Answer:** Separate environments (dev, staging, prod) using same code.

**Simple Example:**
```bash
# Create workspaces
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# Switch workspaces
terraform workspace select dev
terraform apply  # Applies to dev only

terraform workspace select prod
terraform apply  # Applies to prod only
```

**Different configurations per workspace:**
```hcl
variable "instance_type" {
  type = string
}

resource "aws_instance" "web" {
  instance_type = var.instance_type
}
```

**terraform.tfvars.dev**
```hcl
instance_type = "t2.micro"  # Small for dev
```

**terraform.tfvars.prod**
```hcl
instance_type = "t2.xlarge"  # Large for prod
```

**Apply with workspace-specific vars:**
```bash
terraform workspace select dev
terraform apply -var-file="terraform.tfvars.dev"

terraform workspace select prod
terraform apply -var-file="terraform.tfvars.prod"
```

**Check workspace:**
```bash
terraform workspace list
# Shows: * dev, prod, staging
```

**Access workspace name in code:**
```hcl
variable "environment" {
  type = string
}

tags = {
  Environment = terraform.workspace
  # Automatically gets: dev, prod, or staging
}
```

---

## Q: Workspaces vs Directories - Which is better?

**Workspaces:**
- Same code, different state files
- Quick to switch
- Easy for small differences

**Separate Directories:**
- Separate code for each environment
- More control over each
- Harder to keep in sync

**Use Workspaces when:**
- Code is 90% identical
- Just changing variables
- Small team

**Use Directories when:**
- Code significantly different
- Different resources per env
- Large team

---

# IMPORT

## Q: What is Import?

**Simple Answer:** Import existing resources into Terraform so it can manage them.

**Why import?**
- Resources created manually need to be in Terraform
- Migrate from other IaC tools
- Bring existing infrastructure under Terraform control

**Example:**

**Step 1: Create resource definition (without body)**
```hcl
# main.tf
resource "aws_instance" "imported_server" {
  # Leave empty - we'll import the definition
}
```

**Step 2: Import the resource**
```bash
terraform import aws_instance.imported_server i-1234567890abcdef0
# i-1234567890abcdef0 = instance ID in AWS
```

**Step 3: Write the configuration**
```bash
terraform state show aws_instance.imported_server
# Shows all attributes, copy them to main.tf
```

**Result:**
```hcl
resource "aws_instance" "imported_server" {
  ami           = "ami-12345"
  instance_type = "t2.micro"
  # ... all other attributes
}
```

**Now Terraform manages it:**
```bash
terraform plan  # Works with imported resource
terraform apply
```

---

## Q: What is Drift Detection?

**Simple Answer:** Detect when real infrastructure doesn't match Terraform code.

**Causes of Drift:**
- Manual changes in AWS console
- Someone deleted a resource
- Resource was modified by another tool
- Configuration changed outside Terraform

**Check for drift:**
```bash
terraform refresh  # Update state with current reality
terraform plan     # Shows what would change
# If drift exists, plan will show differences
```

**Example:**
```
Terraform code says: Server has 2 disks
Reality: Server has 1 disk (manual deletion)
Action: terraform apply will recreate missing disk
```

**Fix Drift:**
```bash
# Option 1: Accept new state
terraform refresh

# Option 2: Manual fix in AWS, then refresh
# Then update code to match reality
terraform apply

# Option 3: Recreate resource
terraform destroy -target aws_instance.web
terraform apply
```

---

# SECURITY

## Q: Sensitive Data - How to handle secrets?

**NEVER do this:**
```hcl
# BAD!
variable "db_password" {
  default = "MyPassword123"  # DON'T hardcode!
}
```

**DO this instead:**

**Method 1: Environment variable**
```bash
export TF_VAR_db_password="MyPassword123"
terraform apply
```

**Method 2: .tfvars file (GITIGNORED)**
```hcl
# terraform.tfvars (add to .gitignore)
db_password = "MyPassword123"
```

**Method 3: AWS Secrets Manager**
```hcl
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "prod/db/password"
}

resource "aws_rds_instance" "main" {
  password = data.aws_secretsmanager_secret_version.db_password.secret_string
}
```

**Method 4: HashiCorp Vault**
```hcl
data "vault_generic_secret" "db_password" {
  path = "secret/database"
}

resource "aws_rds_instance" "main" {
  password = data.vault_generic_secret.db_password.data["password"]
}
```

**Mark as sensitive:**
```hcl
variable "db_password" {
  type      = string
  sensitive = true  # Hides value in output
}

resource "aws_rds_instance" "main" {
  password = var.db_password
  # Password won't show in logs/output
}
```

---

## Q: What should be in .gitignore?

```
# Never commit these:
terraform.tfstate
terraform.tfstate.*
.terraform/
.terraform.lock.hcl  # Maybe, depending on team
*.tfvars  # Except *.tfvars.example
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.DS_Store
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# Safe to commit:
main.tf
variables.tf
outputs.tf
provider.tf
.terraform.lock.hcl (if using)
*.tfvars.example
README.md
```

---

## Q: What is tfsec?

**Simple Answer:** Security scanner for Terraform code.

**Install:**
```bash
brew install tfsec  # Mac
choco install tfsec  # Windows
```

**Use:**
```bash
tfsec .
# Scans current directory for security issues
```

**Example findings:**
```
- EC2 not encrypted
- S3 bucket publicly accessible
- Security group too open
- Logging not enabled
```

---

## Q: What is Vault?

**Simple Answer:** Secure storage for secrets (passwords, API keys, certificates).

**Why use Vault with Terraform?**
- Centralized secret management
- Automatic rotation
- Audit logging
- Multiple auth methods
- Dynamic credentials

**Basic usage:**
```hcl
provider "vault" {
  address = "https://vault.example.com"
  token   = var.vault_token
}

data "vault_generic_secret" "db_password" {
  path = "secret/prod/database"
}

resource "aws_rds_instance" "main" {
  password = data.vault_generic_secret.db_password.data["password"]
}
```

---

# BACKENDS

## Q: What are Backends?

**Simple Answer:** Where state file is stored (local machine, S3, etc).

**Types:**

**1. Local Backend (default)**
```hcl
# No config needed, terraform.tfstate created locally
```

**2. S3 Backend**
```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "prod/terraform.tfstate"
    region = "us-east-1"
  }
}
```

**3. Terraform Cloud**
```hcl
terraform {
  cloud {
    organization = "my-org"
    workspaces {
      name = "prod"
    }
  }
}
```

**4. Consul**
```hcl
terraform {
  backend "consul" {
    address = "127.0.0.1:8500"
    path    = "terraform/prod"
  }
}
```

---

## Q: Local vs Remote Backend - Which to use?

**Local:**
- Good for: Learning, solo projects
- Bad for: Teams, production
- Risk: Easy to lose/delete

**Remote (S3):**
- Good for: Teams, production, backup
- Bad for: More setup
- Benefits: Collaboration, locking, history

**Rule:** Use local for learning, S3 for real projects.

---

# TROUBLESHOOTING

## Q: How do I debug Terraform?

**Enable debug logging:**
```bash
export TF_LOG=DEBUG
terraform apply
# Shows detailed logs
```

**Log levels:**
```
TF_LOG=TRACE   # Most detailed
TF_LOG=DEBUG   # Detailed
TF_LOG=INFO    # General info
TF_LOG=WARN    # Warnings
TF_LOG=ERROR   # Errors only
```

**Save logs to file:**
```bash
export TF_LOG_PATH=/tmp/terraform.log
terraform apply
# Check /tmp/terraform.log
```

---

## Q: Common Errors and Solutions

**Error: Provider not installed**
```
Solution: terraform init
```

**Error: Resource already exists**
```
Solution: terraform import or remove from code
```

**Error: State lock issue**
```
Solution: terraform force-unlock <id>
```

**Error: Invalid variable**
```
Solution: Check variable type and validation
```

**Error: Resource not found in state**
```
Solution: terraform refresh
```

---

# BEST PRACTICES

## Q: Terraform Best Practices - Top 10

1. **Use Version Control**
   - Commit all .tf files to Git
   - .gitignore state files
   - Code review before merge

2. **Use State Locking**
   - Prevent concurrent changes
   - Use S3 + DynamoDB or Terraform Cloud

3. **Separate Code by Environment**
   - Different directories or workspaces
   - Different .tfvars per environment

4. **Use Modules**
   - DRY principle (Don't Repeat Yourself)
   - Reusable components
   - Better organization

5. **Document Code**
   - Comments in .tf files
   - Description for variables/outputs
   - README.md for projects

6. **Validate Code**
   - `terraform fmt` - Format code
   - `terraform validate` - Check syntax
   - `terraform plan` - Preview changes

7. **Use Variables**
   - Never hardcode values
   - Use .tfvars for different values
   - Validate inputs

8. **Secure Secrets**
   - Never commit secrets to Git
   - Use .gitignore
   - Use Vault or AWS Secrets Manager

9. **Test Before Production**
   - Apply to dev/staging first
   - Review terraform plan output
   - Test functionality

10. **Monitor and Log**
    - Enable state backup
    - Monitor resource changes
    - Audit who changed what

---

## Q: Terraform File Structure Best Practice

```
project/
├── README.md              # Documentation
├── .gitignore            # What not to commit
├── provider.tf           # Provider config
├── variables.tf          # Input variables
├── main.tf              # Main resources
├── outputs.tf           # Output values
├── locals.tf            # Local values (optional)
├── terraform.tfvars     # Variable values
├── terraform.tfvars.example  # Example (commit this)
├── modules/             # Reusable modules
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── ec2/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/        # Environment-specific
│   ├── dev/
│   │   └── terraform.tfvars
│   ├── staging/
│   │   └── terraform.tfvars
│   └── prod/
│       └── terraform.tfvars
└── .terraform/          # Generated (don't commit)
```

---

# CI/CD INTEGRATION

## Q: How to integrate Terraform with Jenkins?

**Jenkinsfile Example:**
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
        // Review plan before applying
      }
    }
    
    stage('Approve') {
      steps {
        input 'Approve Terraform Apply?'
      }
    }
    
    stage('Terraform Apply') {
      steps {
        sh 'terraform apply tfplan'
      }
    }
  }
  
  post {
    always {
      cleanWs()  // Cleanup
    }
  }
}
```

---

## Q: How to integrate Terraform with GitLab CI?

**.gitlab-ci.yml Example:**
```yaml
stages:
  - init
  - plan
  - apply

terraform_init:
  stage: init
  script:
    - terraform init

terraform_plan:
  stage: plan
  script:
    - terraform plan -out=tfplan
  artifacts:
    paths:
      - tfplan

terraform_apply:
  stage: apply
  script:
    - terraform apply tfplan
  only:
    - main  # Only run on main branch
```

---

## Q: Terraform with GitHub Actions?

**.github/workflows/terraform.yml:**
```yaml
name: Terraform

on: [push, pull_request]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - uses: hashicorp/setup-terraform@v1
        with:
          terraform_version: 1.0
      
      - name: Init
        run: terraform init
      
      - name: Format
        run: terraform fmt -check
      
      - name: Validate
        run: terraform validate
      
      - name: Plan
        run: terraform plan
```

---

## Q: Best Practices for CI/CD with Terraform

1. **Separate plan from apply**
   - Plan in PR
   - Apply only on merge

2. **Require approval**
   - Manual approval before apply
   - For production changes

3. **Version control**
   - .terraform.lock.hcl in Git
   - Pin provider versions

4. **Backup state**
   - Enable S3 versioning
   - Regular backups

5. **Audit logging**
   - Track who changed what
   - CloudTrail for AWS

6. **Testing**
   - Validate syntax
   - Check formatting
   - Security scanning (tfsec)

7. **Secrets management**
   - Use CI/CD secrets
   - Never hardcode credentials

---

## Common Interview Questions Summary

**Q: Terraform init, plan, apply - explain each**
- **init**: Download provider plugins
- **plan**: Preview what will happen
- **apply**: Execute the changes

**Q: State file importance**
- Tracks current infrastructure
- Terraform compares code vs state
- Without state, Terraform doesn't know what it created

**Q: Module benefits**
- Reusable code
- Better organization
- Sharing between teams

**Q: Why use variables?**
- Flexibility
- Reusability
- Environment-specific values

**Q: Local vs remote state?**
- Local: Learning, solo projects
- Remote: Teams, production

**Q: How to handle secrets?**
- Use .tfvars with .gitignore
- Use Vault or AWS Secrets Manager
- Mark as sensitive

**Q: Count vs for_each?**
- Count: Simple copies
- For_each: Different configs, better for production

**Q: How to import existing resources?**
- Create empty resource block
- terraform import <resource_type> <id>
- Fill in configuration
- Terraform now manages it

**Q: Provisioners - when to use?**
- Avoid if possible
- Last resort for complex setup
- Better to use user_data or automation tools

---

## Final Tips for Interviews

1. **Understand WHY not just HOW**
   - Why use Terraform? (IaC benefits)
   - Why use modules? (Reusability)
   - Why use remote state? (Collaboration)

2. **Know the workflow**
   - Write → Init → Plan → Apply → Destroy

3. **Know key concepts**
   - State management is critical
   - Variables = flexibility
   - Modules = reusability
   - Security = always important

4. **Practice real examples**
   - Create EC2 instance
   - Create VPC
   - Create RDS
   - Set up modules

5. **Understand trade-offs**
   - Complexity vs simplicity
   - Manual vs automated
   - Local vs remote state

6. **Know common pitfalls**
   - Committing state files to Git
   - Hardcoding secrets
   - No state locking
   - Not backing up state

---

**End of Guide**

Remember: Terraform is about **Infrastructure as Code** - treating infrastructure like software with version control, testing, and automation.

Good luck with your interview! 🚀
