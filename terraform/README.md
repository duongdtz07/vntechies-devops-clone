# Terraform Infrastructure

Multi-environment Terraform setup for AWS infrastructure. State is stored remotely in S3, isolated per environment.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS CLI configured with valid credentials (`aws configure`)
- Access to the `vntechies-bucket` S3 bucket (for remote state)

## Project Structure

See the [Project Structure](#project-structure-1) section below for the full directory layout.

## Usage

All commands must be run from the `terraform/` directory.

### Initialize

Initialize Terraform with the target environment's backend. The `-reconfigure` flag is required when switching environments.

**Dev:**
```bash
terraform init -backend-config=environments/dev/dev.tfbackend -reconfigure
```

**Prod:**
```bash
terraform init -backend-config=environments/prod/prod.tfbackend -reconfigure
```

> **Note:** You must re-initialize whenever you switch environments, because each environment uses a separate S3 state file.

---

### Plan

Preview the changes Terraform will make before applying.

**Dev:**
```bash
terraform plan -var-file=environments/dev/dev.tfvars
```

**Prod:**
```bash
terraform plan -var-file=environments/prod/prod.tfvars
```

---

### Apply

Apply the planned changes to provision or update infrastructure.

**Dev:**
```bash
terraform apply -var-file=environments/dev/dev.tfvars
```

**Prod:**
```bash
terraform apply -var-file=environments/prod/prod.tfvars
```

---

### Destroy

Tear down all resources managed by Terraform in the environment.

**Dev:**
```bash
terraform destroy -var-file=environments/dev/dev.tfvars
```

**Prod:**
```bash
terraform destroy -var-file=environments/prod/prod.tfvars
```

---

## Full Workflow Example

```bash
# 1. Initialize for dev
terraform init -backend-config=environments/dev/dev.tfbackend -reconfigure

# 2. Preview changes
terraform plan -var-file=environments/dev/dev.tfvars

# 3. Apply changes
terraform apply -var-file=environments/dev/dev.tfvars

# --- Switch to prod ---

# 4. Re-initialize for prod
terraform init -backend-config=environments/prod/prod.tfbackend -reconfigure

# 5. Preview prod changes
terraform plan -var-file=environments/prod/prod.tfvars

# 6. Apply to prod
terraform apply -var-file=environments/prod/prod.tfvars
```

---

## CI/CD with GitHub Actions

Two workflow files automate the full promotion pipeline:

| File | Trigger | Purpose |
|---|---|---|
| [`terraform-pr.yml`](../.github/workflows/terraform-pr.yml) | PR targeting `main` | Validate + Plan + PR comment |
| [`terraform-deploy.yml`](../.github/workflows/terraform-deploy.yml) | Push to `main` | Deploy DEV → PROD |

### Pipeline flow

```
Feature Branch
      │
  Pull Request ──────────────────────────────────────────────────
      │                                                          │
  Validate                                                  Plan Dev
      │                                                          │
      └──────────────────────┬───────────────────────────────────┘
                             │
                       PR Comment (validate status + plan output)
                             │
                    Reviewer Approval + Merge
                             │
                       ┌─────▼─────┐
                       │ Deploy DEV │  (automatic)
                       └─────┬─────┘
                             │
                    Integration Test  (automatic)
                             │
                    ┌────────▼────────┐
                    │  Deploy PROD    │  (manual approval required)
                    └─────────────────┘
```

### One-time GitHub setup

**Step 1 — Create two environments**

Go to **Settings → Environments** and create:
- `dev` — no restrictions
- `prod` — add Required Reviewers (mandatory sign-off)

**Step 2 — Add secrets to each environment**

Under each environment add:

| Secret name | Value |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS access key for that environment |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key for that environment |

> Use separate IAM users per environment so a leaked dev key cannot touch prod.

**Step 3 — Protect the `main` branch**

Go to **Settings → Branches**, add a rule for `main`:
- Require a pull request before merging
- Require these status checks to pass: `Validate`, `Plan / Dev`

This enforces that every change goes through the PR workflow before it can be deployed.

**Step 4 — Customize the integration test**

Open [`.github/workflows/terraform-deploy.yml`](../.github/workflows/terraform-deploy.yml) and replace the placeholder steps in the `integration-test` job with your actual tests (e.g. `pytest`, health-check `curl`, AWS CLI assertions).

---

## Project Structure

```
terraform/
├── environments/
│   ├── dev/
│   │   ├── dev.tfbackend   # S3 state path for dev
│   │   └── dev.tfvars      # Variable values for dev
│   └── prod/
│       ├── prod.tfbackend  # S3 state path for prod
│       └── prod.tfvars     # Variable values for prod
├── providers.tf
├── variables.tf
├── ec2.tf
├── rds.tf
├── vpc.tf
└── outputs.tf
```

---

## Environment Differences

| Variable        | Dev        | Prod       |
|----------------|------------|------------|
| `env`           | `dev`      | `prod`     |
| `instance_type` | `t3.micro` | `t3.small` |
| State file      | `terraform/dev/terraform.tfstate` | `terraform/prod/terraform.tfstate` |
