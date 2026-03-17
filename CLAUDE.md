# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Terraform repository for GCP sandbox infrastructure. Deploys via GitHub Actions using Workload Identity Federation (no stored SA keys). Remote state lives in GCS bucket `tfstate-7ceba286-c3bb-4d79`.

## Common Commands

```bash
# Local development
terraform init
terraform fmt -recursive
terraform validate
terraform plan -var="project_id=YOUR_PROJECT_ID"
terraform apply -var="project_id=YOUR_PROJECT_ID"
terraform destroy -var="project_id=YOUR_PROJECT_ID"
```

## CI/CD Workflows

| Workflow | Trigger | Action |
|---|---|---|
| `terraform-plan.yml` | PR opened / updated | Runs plan, posts output as PR comment |
| `terraform-apply.yml` | Push to `main` (PR merged) | Runs `terraform apply` |
| `terraform-destroy.yml` | Manual (`workflow_dispatch`) or scheduled cron | Runs `terraform destroy` |

Destroy requires typing `"destroy"` in the manual trigger confirmation input. To enable scheduled auto-destroy, uncomment the `schedule` block in `terraform-destroy.yml`.

## Repository Setup (one-time)

### 1. Workload Identity Federation (GCP auth for GitHub Actions)

```bash
export PROJECT_ID="your-gcp-project-id"
export GITHUB_REPO="rbecerrav/terraform-gcp-sandbox"
bash scripts/setup-wif.sh
```

The script outputs 3 values — add them as **GitHub Actions secrets**:
- `WIF_PROVIDER`
- `WIF_SERVICE_ACCOUNT`
- `GCP_PROJECT_ID`

### 2. GitHub Branch Protection (enforce PR reviews)

In GitHub → repo Settings → Branches → Add rule for `main`:
- [x] Require a pull request before merging
- [x] Require approvals: **1**
- [x] Dismiss stale reviews when new commits are pushed
- [x] Require status checks to pass: `Terraform Plan`
- [x] Require branches to be up to date before merging
- [x] Do not allow bypassing the above settings

### 3. Add Collaborator

GitHub → Settings → Collaborators → Add people → set role to **Write**.
They can push branches and open PRs but cannot merge without your approval.

## Architecture

```
.
├── versions.tf      # Terraform version, GCS backend, provider versions
├── providers.tf     # google provider (project/region from variables)
├── variables.tf     # project_id, region
├── main.tf          # GCP resources
├── outputs.tf       # Outputs
├── scripts/
│   └── setup-wif.sh # One-time GCP Workload Identity Federation bootstrap
└── .github/workflows/
    ├── terraform-plan.yml    # PR check
    ├── terraform-apply.yml   # Merge to main
    └── terraform-destroy.yml # Manual / scheduled destroy
```

## Destroy Strategy

- **Manual on-demand**: Go to Actions → Terraform Destroy → Run workflow → type `destroy`
- **Scheduled**: Uncomment the `schedule` cron in `terraform-destroy.yml` (e.g. every Friday night)
- The GCS state bucket is intentionally NOT destroyed — recreating it is manual overhead
