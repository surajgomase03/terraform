# Terraform Workspace vs tfvars File

## 1. Terraform Workspace

-   Used to create multiple **state files** for same Terraform code.
-   Helps manage environments like **dev, qa, stage, prod**.
-   Each workspace maintains its **own state file**.
-   Code is same → state is different.
-   Commands:
    -   `terraform workspace list`
    -   `terraform workspace new dev`
    -   `terraform workspace select prod`

------------------------------------------------------------------------

## 2. .tfvars File

-   Stores **environment‑specific variable values**.
-   Used to pass inputs like:
    -   instance type
    -   region
    -   bucket name
    -   tags
-   Loaded using:
    -   `terraform apply -var-file="dev.tfvars"`

------------------------------------------------------------------------

## Summary Table

  Feature       Workspace                  .tfvars
  ------------- -------------------------- ------------------------------
  Purpose       Separate **state files**   Separate **variable values**
  Environment   dev/prod state mgmt        dev/prod config values
  Controls      State                      Inputs
  Command       `terraform workspace`      `-var-file=dev.tfvars`
  Same code?    ✔ Yes                      ✔ Yes
