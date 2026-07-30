# Terraform Infrastructure

Multi-environment Terraform setup for AWS infrastructure. State is stored remotely in S3, isolated per environment.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS CLI configured with valid credentials (`aws configure`)
- Access to the `vntechies-bucket` S3 bucket (for remote state)

## Project Structure

```
terraform/
├── backend/
│   ├── dev.tfbackend       # Backend config for dev (S3 state path)
│   └── prod.tfbackend      # Backend config for prod (S3 state path)
├── dev.tfvars              # Variable values for dev environment
├── prod.tfvars             # Variable values for prod environment
├── providers.tf            # Terraform & provider requirements
├── variables.tf            # Variable declarations
├── ec2.tf                  # EC2 resources
├── rds.tf                  # RDS resources
├── vpc.tf                  # VPC & networking
└── outputs.tf              # Output values
```

## Usage

All commands must be run from the `terraform/` directory.

### Initialize

Initialize Terraform with the target environment's backend. The `-reconfigure` flag is required when switching environments.

**Dev:**
```bash
terraform init -backend-config=backend/dev.tfbackend -reconfigure
```

**Prod:**
```bash
terraform init -backend-config=backend/prod.tfbackend -reconfigure
```

> **Note:** You must re-initialize whenever you switch environments, because each environment uses a separate S3 state file.

---

### Plan

Preview the changes Terraform will make before applying.

**Dev:**
```bash
terraform plan -var-file=dev.tfvars
```

**Prod:**
```bash
terraform plan -var-file=prod.tfvars
```

---

### Apply

Apply the planned changes to provision or update infrastructure.

**Dev:**
```bash
terraform apply -var-file=dev.tfvars
```

**Prod:**
```bash
terraform apply -var-file=prod.tfvars
```

Add `-auto-approve` to skip the interactive confirmation prompt (use with caution):
```bash
terraform apply -var-file=dev.tfvars -auto-approve
```

---

### Destroy

Tear down all resources managed by Terraform in the environment.

**Dev:**
```bash
terraform destroy -var-file=dev.tfvars
```

**Prod:**
```bash
terraform destroy -var-file=prod.tfvars
```

---

## Full Workflow Example

```bash
# 1. Initialize for dev
terraform init -backend-config=backend/dev.tfbackend -reconfigure

# 2. Preview changes
terraform plan -var-file=dev.tfvars

# 3. Apply changes
terraform apply -var-file=dev.tfvars

# --- Switch to prod ---

# 4. Re-initialize for prod
terraform init -backend-config=backend/prod.tfbackend -reconfigure

# 5. Preview prod changes
terraform plan -var-file=prod.tfvars

# 6. Apply to prod
terraform apply -var-file=prod.tfvars
```

---

## Environment Differences

| Variable        | Dev         | Prod        |
|----------------|-------------|-------------|
| `env`           | `dev`       | `prod`      |
| `instance_type` | `t3.micro`  | `t3.small`  |
| State file      | `terraform/dev/terraform.tfstate` | `terraform/prod/terraform.tfstate` |
