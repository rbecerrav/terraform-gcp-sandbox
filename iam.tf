# --- Service Account: Scrapers ---

resource "google_service_account" "scraper" {
  account_id   = "scraper-sa"
  display_name = "Scraper Service Account"
  description  = "Used by Cloud Run scraper services to connect to Cloud SQL and read secrets"
  project      = var.project_id
}

resource "google_project_iam_member" "scraper_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.scraper.email}"
}

# IAM a nivel de secreto individual (menor privilegio)
# scraper-sa necesita: db-name, db-user, db-password, capsolver-api-key

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

resource "google_secret_manager_secret_iam_member" "scraper_capsolver_api_key" {
  secret_id = google_secret_manager_secret.capsolver_api_key.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

# --- Service Account: API Backend ---

resource "google_service_account" "api" {
  account_id   = "api-sa"
  display_name = "API Service Account"
  description  = "Used by Cloud Run API backend to connect to Cloud SQL and read secrets"
  project      = var.project_id
}

resource "google_project_iam_member" "api_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.api.email}"
}

# IAM a nivel de secreto individual (menor privilegio)
# api-sa necesita: db-name, db-user, db-password (NO capsolver-api-key)

resource "google_secret_manager_secret_iam_member" "api_db_name" {
  secret_id = google_secret_manager_secret.db_name.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_db_user" {
  secret_id = google_secret_manager_secret.db_user.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

resource "google_secret_manager_secret_iam_member" "api_db_password" {
  secret_id = google_secret_manager_secret.db_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.api.email}"
}

# --- IAM: scraper-sa accede a secretos de credenciales de portal ---
# Menor privilegio: solo los 4 secretos necesarios para resolver credenciales en runtime

resource "google_secret_manager_secret_iam_member" "scraper_jet_exc_email" {
  secret_id = google_secret_manager_secret.jet_exc_email.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

resource "google_secret_manager_secret_iam_member" "scraper_jet_exc_password" {
  secret_id = google_secret_manager_secret.jet_exc_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

resource "google_secret_manager_secret_iam_member" "scraper_fly_belair_email" {
  secret_id = google_secret_manager_secret.fly_belair_email.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

resource "google_secret_manager_secret_iam_member" "scraper_fly_belair_password" {
  secret_id = google_secret_manager_secret.fly_belair_password.secret_id
  project   = var.project_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.scraper.email}"
}

# --- IAM: scraper-sa puede invocar Cloud Run (necesario para Cloud Scheduler OIDC) ---

resource "google_cloud_run_v2_service_iam_member" "scraper_invoker" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.session_service.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scraper.email}"
}
