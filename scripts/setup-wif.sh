#!/usr/bin/env bash
# =============================================================================
# setup-wif.sh  (DEPRECATED — use cicd.tf instead)
#
# This script was the original one-time bootstrap for Workload Identity
# Federation.  Terraform now manages all WIF resources via cicd.tf:
#   - Service Account: github-actions-cicd
#   - Workload Identity Pool: github-actions-pool
#   - Workload Identity Provider: github-oidc
#   - IAM bindings (artifactregistry.writer, run.admin, cloudscheduler.admin,
#     iam.serviceAccountUser on scraper-sa)
#
# The script is kept ONLY as a reference for understanding the bootstrap flow.
# Do NOT run it — it would create a duplicate SA with different permissions.
#
# If you need to bootstrap a brand-new project where Terraform cannot yet
# authenticate, use the minimal bootstrap below instead of this script:
#
#   1. Create the SA manually:
#      gcloud iam service-accounts create github-actions-cicd \
#        --display-name="GitHub Actions CI/CD" --project=$PROJECT_ID
#
#   2. Grant only the permissions needed for the first terraform apply:
#      gcloud projects add-iam-policy-binding $PROJECT_ID \
#        --member="serviceAccount:github-actions-cicd@$PROJECT_ID.iam.gserviceaccount.com" \
#        --role="roles/editor" --condition=None
#      (Terraform will replace this with granular roles on first apply)
#
#   3. Create the WIF pool + provider (Terraform will import or recreate):
#      gcloud iam workload-identity-pools create github-actions-pool ...
#      gcloud iam workload-identity-pools providers create-oidc github-oidc ...
#
#   4. After first `terraform apply`, revoke roles/editor:
#      gcloud projects remove-iam-policy-binding $PROJECT_ID \
#        --member="serviceAccount:github-actions-cicd@$PROJECT_ID.iam.gserviceaccount.com" \
#        --role="roles/editor"
#
# =============================================================================
echo "ERROR: This script is deprecated. WIF is managed by Terraform (cicd.tf)."
echo "See comments in this file for bootstrap instructions."
exit 1
