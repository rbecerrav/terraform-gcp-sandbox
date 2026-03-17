#!/usr/bin/env bash
# =============================================================================
# setup-wif.sh
# Sets up Workload Identity Federation so GitHub Actions can authenticate
# to GCP without storing any service account keys as GitHub secrets.
#
# Usage:
#   export PROJECT_ID="your-gcp-project-id"
#   export GITHUB_REPO="your-github-username/terraform-gcp-sandbox"
#   bash scripts/setup-wif.sh
# =============================================================================
set -euo pipefail

: "${PROJECT_ID:?Set PROJECT_ID env var}"
: "${GITHUB_REPO:?Set GITHUB_REPO env var (e.g. rbecerrav/terraform-gcp-sandbox)}"

PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
POOL_ID="github-actions-pool"
PROVIDER_ID="github-actions-provider"
SA_NAME="github-actions-sa"
SA_EMAIL="${SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

echo "==> Enabling required APIs..."
gcloud services enable iamcredentials.googleapis.com \
  --project="${PROJECT_ID}"

echo "==> Creating Service Account: ${SA_EMAIL}"
gcloud iam service-accounts create "${SA_NAME}" \
  --display-name="GitHub Actions Service Account" \
  --project="${PROJECT_ID}" || echo "Service account already exists, continuing..."

echo "==> Granting roles to Service Account..."
# Adjust roles to match what your Terraform resources actually need
for ROLE in \
  "roles/editor" \
  "roles/storage.admin" \
  "roles/iam.serviceAccountTokenCreator"; do
  gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${SA_EMAIL}" \
    --role="${ROLE}" \
    --condition=None
done

echo "==> Creating Workload Identity Pool: ${POOL_ID}"
gcloud iam workload-identity-pools create "${POOL_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool" \
  --project="${PROJECT_ID}" || echo "Pool already exists, continuing..."

echo "==> Creating Workload Identity Provider: ${PROVIDER_ID}"
gcloud iam workload-identity-pools providers create-oidc "${PROVIDER_ID}" \
  --location="global" \
  --workload-identity-pool="${POOL_ID}" \
  --display-name="GitHub Actions Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project="${PROJECT_ID}" || echo "Provider already exists, continuing..."

echo "==> Binding Service Account to Workload Identity Pool (repo: ${GITHUB_REPO})"
gcloud iam service-accounts add-iam-policy-binding "${SA_EMAIL}" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/attribute.repository/${GITHUB_REPO}"

WIF_PROVIDER="projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"

echo ""
echo "============================================================"
echo "SUCCESS. Add these as GitHub Actions secrets in your repo:"
echo "  WIF_PROVIDER         = ${WIF_PROVIDER}"
echo "  WIF_SERVICE_ACCOUNT  = ${SA_EMAIL}"
echo "  GCP_PROJECT_ID       = ${PROJECT_ID}"
echo "============================================================"
