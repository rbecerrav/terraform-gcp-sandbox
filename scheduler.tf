# --- Cloud Scheduler: Session login jobs ---
#
# Cada job envía NOMBRES de secretos (no valores reales) al endpoint de login.
# El servicio resuelve los valores en runtime consultando GCP Secret Manager.
#
# Autenticación: OIDC token de scraper-sa — Cloud Run valida automáticamente.

resource "google_cloud_scheduler_job" "session_login_jet_exc" {
  name      = "session-login-jet-exc"
  schedule  = var.scheduler_login_cron
  time_zone = var.scheduler_timezone
  project   = var.project_id
  region    = var.region

  http_target {
    uri         = "${google_cloud_run_v2_service.session_service.uri}/api/v1/session/login"
    http_method = "POST"

    headers = {
      "Content-Type" = "application/json"
    }

    # Solo nombres de secretos — ningún valor sensible queda en Terraform ni en tfstate
    body = base64encode(jsonencode({
      company_id      = "1"
      email_secret    = "jet-exc-email"
      password_secret = "jet-exc-password"
    }))

    oidc_token {
      service_account_email = google_service_account.scraper.email
      audience              = google_cloud_run_v2_service.session_service.uri
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "10s"
    max_backoff_duration = "400s"
    max_doublings        = 3
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_service.session_service,
    google_cloud_run_v2_service_iam_member.scraper_invoker,
    google_secret_manager_secret.jet_exc_email,
    google_secret_manager_secret.jet_exc_password,
  ]
}

resource "google_cloud_scheduler_job" "session_login_fly_belair" {
  name      = "session-login-fly-belair"
  schedule  = var.scheduler_login_cron
  time_zone = var.scheduler_timezone
  project   = var.project_id
  region    = var.region

  http_target {
    uri         = "${google_cloud_run_v2_service.session_service.uri}/api/v1/session/login"
    http_method = "POST"

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      company_id      = "2"
      email_secret    = "fly-belair-email"
      password_secret = "fly-belair-password"
    }))

    oidc_token {
      service_account_email = google_service_account.scraper.email
      audience              = google_cloud_run_v2_service.session_service.uri
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "10s"
    max_backoff_duration = "400s"
    max_doublings        = 3
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_service.session_service,
    google_cloud_run_v2_service_iam_member.scraper_invoker,
    google_secret_manager_secret.fly_belair_email,
    google_secret_manager_secret.fly_belair_password,
  ]
}
