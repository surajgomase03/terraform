ALB (Application Load Balancer) - Quick setup

Files added:
- `alb.tf` : creates ALB, target group, listener, security group, two example EC2 instances, and attachments.

How to use

1. Ensure AWS provider is configured (provider block or env vars `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`).
2. From `HandsOn/Projects/Project1` run:

```powershell
terraform init
terraform plan -out=alb-plan.tfplan
terraform apply "alb-plan.tfplan"
```

Notes & cautions
- The example uses `remote-exec` provisioners on the EC2 instances; these require SSH access (key pair, security group rules). Remove or adjust `provisioner` blocks if you don't have SSH configured.
- The ALB subnets reference `aws_subnet.public_subnet1` and `public_subnet2` in this same folder; ensure those resources exist (they're in `main.tf`).
- This config creates resources that will incur AWS charges; destroy them when finished:

```powershell
terraform destroy
```

If you want a version without provisioners (no remote-exec), tell me and I'll create a simplified `alb-no-provisioners.tf`.
