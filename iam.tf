# =============================================================================
# IAM — Service Accounts y bindings
# =============================================================================
# Dos SAs de runtime con permisos segregados (menor privilegio):
#   session-sa  → session-service-api (portal login, CapSolver, DB)
#   scraper-sa  → 7 scrapers ETL (solo DB)
# =============================================================================

# --- Service Account: session-service-api ---

resource "google_service_account" "session" {
  account_id   = "session-sa"
  display_name = "Session Service Account"
  description  = "Used by session-service-api for portal login, CapSolver, and DB access"
  project      = var.project_id
}

resource "google_project_iam_member" "session_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.session.email}"
}

# IAM a nivel de secreto individual — session-sa necesita DB + CapSolver + credenciales de portal

resource "google_secret_manager_secret_iam_member" "session_db_name" {
  secret_id = google_secret_manager_secret.db_name.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_db_user" {
  secret_id = google_secret_manager_secret.db_user.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_db_password" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_capsolver_api_key" {
  secret_id = google_secret_manager_secret.capsolver_api_key.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_jet_exc_email" {
  secret_id = google_secret_manager_secret.jet_exc_email.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_jet_exc_password" {
  secret_id = google_secret_manager_secret.jet_exc_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_fly_belair_email" {
  secret_id = google_secret_manager_secret.fly_belair_email.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

resource "google_secret_manager_secret_iam_member" "session_fly_belair_password" {
  secret_id = google_secret_manager_secret.fly_belair_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.session.email}"
}

# --- IAM: session-sa puede invocar session-service-api (Cloud Scheduler OIDC para login jobs) ---

resource "google_cloud_run_v2_service_iam_member" "session_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.session_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.session.email}"
}

# --- Service Account: Scrapers ---

resource "google_service_account" "scraper" {
  account_id   = "scraper-sa"
  display_name = "Scraper Service Account"
  description  = "Used by Cloud Run scraper services to connect to Cloud SQL and read DB secrets"
  project      = var.project_id
}

resource "google_project_iam_member" "scraper_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.scraper.email}"
}

# IAM a nivel de secreto individual — scraper-sa solo necesita secretos de BD
# (capsolver y credenciales de portal son exclusivos de session-sa)

resource "google_secret_manager_secret_iam_member" "scraper_db_name" {
  secret_id = google_secret_manager_secret.db_name.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

resource "google_secret_manager_secret_iam_member" "scraper_db_user" {
  secret_id = google_secret_manager_secret.db_user.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

resource "google_secret_manager_secret_iam_member" "scraper_db_password" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}
