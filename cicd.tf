# =============================================================================
# CI/CD — Workload Identity Federation + GitHub Actions
# =============================================================================
# Propósito: permitir que GitHub Actions autentique contra GCP sin credenciales
# estáticas (sin service account keys). Usa OIDC tokens efímeros via WIF.
#
# Recursos creados:
#   - SA dedicado para CI/CD (github-actions-cicd) con permisos mínimos
#   - Workload Identity Pool para GitHub Actions
#   - Workload Identity Provider (OIDC de GitHub)
#   - IAM binding: pool → SA (impersonation)
#   - IAM binding: SA → Artifact Registry writer
# =============================================================================

# --- Service Account dedicado para CI/CD ---
# Solo puede hacer push de imágenes. No tiene acceso a secretos, Cloud SQL ni Cloud Run.

resource "google_service_account" "cicd" {
  account_id   = "github-actions-cicd"
  display_name = "GitHub Actions CI/CD"
  description  = "Used by GitHub Actions to build and push Docker images to Artifact Registry. No runtime permissions."
  project      = var.project_id
}

# --- IAM: permiso para push a Artifact Registry ---
# roles/artifactregistry.writer: puede push/pull imágenes, NO puede administrar el repositorio

resource "google_artifact_registry_repository_iam_member" "cicd_ar_writer" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.docker.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${google_service_account.cicd.email}"
}

# --- IAM: permisos para terraform apply desde GitHub Actions ---

# Crear/actualizar Cloud Run services y gestionar IAM sobre ellos (setIamPolicy)
resource "google_project_iam_member" "cicd_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
}

# Crear/actualizar Cloud Scheduler jobs
resource "google_project_iam_member" "cicd_scheduler_admin" {
  project = var.project_id
  role    = "roles/cloudscheduler.admin"
  member  = "serviceAccount:${google_service_account.cicd.email}"
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

  # Solo acepta tokens del repo configurado en var.github_repo.
  # Nota de seguridad: esta condicion permite cualquier branch del repo.
  # terraform-plan.yml (PRs) necesita acceso GCP desde branches no-main.
  # terraform-apply.yml solo se ejecuta en push a main (protegido por GitHub branch rules).
  # Para repos publicos o con colaboradores externos, considerar restringir a:
  #   "assertion.repository == '...' && assertion.ref == 'refs/heads/main'"
  #   y crear un SA de solo lectura separado para plan en PRs.
  attribute_condition = "assertion.repository == '${var.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# --- IAM: permitir al pool impersonar el SA de CI/CD ---
# Cualquier workflow del repo configurado puede obtener un token efímero del SA

resource "google_service_account_iam_member" "cicd_workload_identity_user" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
