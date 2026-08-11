# Terraform Infrastructure

Multi-environment Terraform setup for AWS infrastructure. State is stored remotely in S3, isolated per environment.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- AWS CLI configured with valid credentials (`aws configure`)
- Access to the `vntechies-bucket` S3 bucket (for remote state)

## Project Structure

See the [Project Structure](#project-structure-1) section below for the full directory layout.

## Resource Tagging

All AWS resources are tagged with a shared set of labels defined in [`locals.tf`](locals.tf):

| Tag | Example value | Set by |
|---|---|---|
| `env` | `dev` / `prod` | `*.tfvars` |
| `managed_by` | `terraform` | `locals.tf` (hardcoded) |
| `release_version` | `v1.2.3` / `dev-abc1234` | CI/CD via `-var release_version=...` |

Each resource merges these common tags with its own `Name`:

```hcl
tags = merge(local.common_tags, {
  Name = "${var.env}-my-resource"
})
```

**How `release_version` is set:**

| Context | Value | How |
|---|---|---|
| Prod release (`v*.*.*` tag) | `v1.2.3` | `terraform-release.yml` passes `-var "release_version=${{ github.ref_name }}"` |
| Dev merge to `main` | `dev-abc1234` | `terraform-deploy.yml` passes `-var "release_version=dev-${GITHUB_SHA:0:7}"` |
| Local development | `untagged` | Variable default in `variables.tf` |

To filter all resources belonging to a specific release in the AWS console:
- Go to **Resource Groups & Tag Editor**
- Filter by tag key `release_version` = `v1.2.3`

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

Four workflow files implement a GitOps promotion pipeline. Git is the single source of truth — every infrastructure change flows through a PR, and every prod deployment is an explicit, versioned tag.

| File | Trigger | Purpose |
|---|---|---|
| [`terraform-pr.yml`](../.github/workflows/terraform-pr.yml) | PR targeting `main` | Validate + plan both envs + PR comment |
| [`terraform-deploy.yml`](../.github/workflows/terraform-deploy.yml) | Push to `main` | Auto-deploy to DEV + integration tests |
| [`terraform-release.yml`](../.github/workflows/terraform-release.yml) | `v*.*.*` tag push | Deploy to PROD (manual approval gate) |
| [`terraform-drift.yml`](../.github/workflows/terraform-drift.yml) | Weekday 06:00 UTC schedule | Detect infra drift, open GitHub Issue |

### Pipeline flow

```
feature/* branch
      │
  Pull Request ─────────────────────────────────────────────────────
      │                     │                     │
  Validate              Plan / Dev            Plan / Prod
      │                     │                     │
      └─────────────────────┴──────────────────────┘
                            │
                  PR Comment (validate + dev plan + prod plan)
                            │
               Reviewer approves + merges to main
                            │
                  ┌─────────▼─────────┐
                  │   Plan / Dev       │  (saves binary tfplan artifact)
                  └─────────┬─────────┘
                            │
                  ┌─────────▼─────────┐
                  │   Apply / Dev      │  (applies exact saved plan)
                  └─────────┬─────────┘
                            │
                  ┌─────────▼─────────┐
                  │  Integration Test  │  (automatic)
                  └───────────────────┘

             ── to release to prod ──

  git tag v1.2.3 && git push --tags
                            │
                  ┌─────────▼─────────┐
                  │   Plan / Prod      │  (saves binary tfplan artifact)
                  └─────────┬─────────┘
                            │
                  ┌─────────▼─────────┐
                  │  Manual Approval   │  (reviewer inspects plan artifact)
                  └─────────┬─────────┘
                            │
                  ┌─────────▼─────────┐
                  │   Apply / Prod     │  (applies exact saved plan)
                  └───────────────────┘
```

### Releasing to production

Production deploys are triggered by a git tag, never by a branch push. This gives every prod deployment an immutable, auditable release marker.

```bash
# 1. Merge your feature PR to main (auto-deploys to dev)

# 2. Once dev is validated, tag the commit for prod
git tag v1.2.3
git push --tags
```

This starts the `terraform-release.yml` workflow:
1. **Plan** runs automatically and saves the binary plan as an artifact
2. The workflow **pauses** waiting for a reviewer to approve in the GitHub UI
3. The reviewer inspects the plan artifact, then clicks **Approve and deploy**
4. **Apply** runs against the exact saved plan — no re-plan, no surprises

### Rolling back production

Because every prod deploy is a tagged commit, rolling back means tagging an earlier known-good commit:

```bash
# Find the last good release tag
git log --oneline --decorate | grep 'tag: v'

# Tag the previous release commit as the new release
git tag v1.2.4 <commit-sha>
git push --tags
```

This triggers a fresh plan + apply from the good commit. Terraform reconciles to that state automatically.

> **Do not manually run `terraform apply` in prod.** All prod changes must flow through the tag-based release so the state file, the plan artifact, and the git tag stay in sync.

---

### One-time GitHub setup

**Step 1 — Create three environments**

Go to **Settings → Environments** and create:

| Environment | Required reviewers | Purpose |
|---|---|---|
| `dev` | None | Dev deployments (automatic) |
| `prod-plan` | None | Prod planning in PRs and drift checks (read-only) |
| `prod` | **Yes — add reviewers** | Prod apply (gated) |

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
- Require these status checks to pass: `Validate`, `Plan / Dev`, `Plan / Prod`
- Require linear history (prevents direct pushes)

**Step 4 — Restrict `prod` environment to tags only**

In **Settings → Environments → prod**, under Deployment branches and tags:
- Select **Selected branches and tags**
- Add tag pattern: `v*`

This ensures prod can only be deployed from a version tag, never from a raw branch push.

**Step 5 — Customize the integration test**

Open [`.github/workflows/terraform-deploy.yml`](../.github/workflows/terraform-deploy.yml) and replace the placeholder steps in the `integration-test` job with your actual tests (e.g. `pytest`, health-check `curl`, AWS CLI assertions).

**Step 6 — Add `infrastructure` and `drift` labels**

The drift detection workflow opens issues with these labels. Go to **Issues → Labels** and create them if they don't exist.

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
