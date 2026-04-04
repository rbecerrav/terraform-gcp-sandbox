# =============================================================================
# CI/CD — Workload Identity Federation + GitHub Actions
# =============================================================================
# Propósito: permitir que GitHub Actions autentique contra GCP sin credenciales
# estáticas (sin service account keys). Usa OIDC tokens efímeros via WIF.
#
# Recursos creados:
#   - SA dedicado para CI/CD (github-actions-cicd)
#   - Workload Identity Pool para GitHub Actions
#   - Workload Identity Provider (OIDC de GitHub)
#   - IAM bindings: pool → SA (impersonation) para repo de servicios e infra
#   - IAM roles necesarios para terraform apply (gestión de todos los recursos)
# =============================================================================

# --- Service Account dedicado para CI/CD ---

resource "google_service_account" "cicd" {
  account_id   = "github-actions-cicd"
  display_name = "GitHub Actions CI/CD"
  description  = "Used by GitHub Actions to run terraform plan/apply and push Docker images. Has admin roles scoped to services managed by this repo."
  project      = var.project_id
}

# --- IAM: roles necesarios para terraform plan/apply ---
# Cada rol cubre exactamente los recursos que Terraform gestiona en este repo.

locals {
  cicd_project_roles = [
    "roles/run.admin",                       # Cloud Run services + IAM bindings
    "roles/cloudscheduler.admin",            # Cloud Scheduler jobs
    "roles/cloudsql.admin",                  # Cloud SQL instances, databases, users
    "roles/secretmanager.admin",             # Secret Manager secrets + versions + IAM
    "roles/artifactregistry.admin",          # Artifact Registry repos + IAM
    "roles/iam.serviceAccountAdmin",         # Service accounts CRUD
    "roles/iam.workloadIdentityPoolAdmin",   # WIF pools + providers
    "roles/resourcemanager.projectIamAdmin", # google_project_iam_member resources
    "roles/monitoring.admin",                # Alert policies + notification channels
    "roles/logging.admin",                   # Log-based metrics
    "roles/compute.networkAdmin",            # VPC networks + global addresses + firewalls
    "roles/compute.instanceAdmin.v1",        # Compute Engine instances (bastion VM)
    "roles/servicenetworking.networksAdmin", # Private Service Access connections
    "roles/serviceusage.serviceUsageAdmin",  # Habilitar/deshabilitar GCP APIs
  ]
}

resource "google_project_iam_member" "cicd_roles" {
  for_each = toset(local.cicd_project_roles)

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# --- IAM: permiso para push a Artifact Registry (repo-level) ---

resource "google_artifact_registry_repository_iam_member" "cicd_ar_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd.email}"
}

# Necesario para asignar service accounts a Cloud Run services en terraform apply
resource "google_service_account_iam_member" "cicd_act_as_scraper" {
  service_account_id = google_service_account.scraper.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_service_account_iam_member" "cicd_act_as_session" {
  service_account_id = google_service_account.session.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

resource "google_service_account_iam_member" "cicd_act_as_bastion" {
  service_account_id = google_service_account.bastion.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

# --- Workload Identity Pool ---
# Contenedor lógico de proveedores de identidad externos (en este caso GitHub)

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github-actions-pool"
  display_name              = "GitHub Actions Pool"
  description               = "Identity pool for GitHub Actions OIDC authentication"
  project                   = var.project_id

  depends_on = [google_project_service.apis]
}

# --- Workload Identity Provider (GitHub OIDC) ---
# Mapea los claims del token OIDC de GitHub a atributos de Google
# attribute_condition restringe el acceso al repo específico de este proyecto

resource "google_iam_workload_identity_pool_provider" "github_oidc" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github-oidc"
  display_name                       = "GitHub OIDC Provider"
  description                        = "OIDC provider for GitHub Actions — restricts access to the scraper repository"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  # Acepta tokens de dos repos:
  #   1. var.github_repo (Fraktal-JetExcellence-Scrappers) — build y push de imágenes
  #   2. terraform-gcp-sandbox (este repo) — terraform plan/apply desde GitHub Actions
  # Nota: cualquier branch de ambos repos puede autenticarse.
  # El control de qué se despliega lo da la branch protection de main en cada repo.
  attribute_condition = "assertion.repository == '${var.github_repo}' || assertion.repository == 'rbecerrav/terraform-gcp-sandbox'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- IAM: permitir al pool impersonar el SA de CI/CD ---

# Repo de servicios (build + push de imágenes, GitOps dispatch)
resource "google_service_account_iam_member" "cicd_workload_identity_user" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}

# Repo de infra (terraform plan/apply desde GitHub Actions)
resource "google_service_account_iam_member" "cicd_workload_identity_user_infra" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/rbecerrav/terraform-gcp-sandbox"
}
