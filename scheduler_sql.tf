# =============================================================================
# Cloud Scheduler — Cloud SQL start / stop (cost reduction)
# =============================================================================

# Necesario para obtener el project number del agente de servicio de Cloud Scheduler
data "google_project" "project" {
  project_id = var.project_id
}

# Cloud Scheduler service agent necesita actAs sobre el cicd SA para usar oauth_token
resource "google_service_account_iam_member" "cloudscheduler_act_as_cicd" {
  service_account_id = google_service_account.cicd.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
}
# Enciende Cloud SQL a las 4:00 AM (1h antes del primer scraper) y la apaga
# a las 9:30 AM (15 min después del último scraper a las 8:15 AM).
#
# Ahorro estimado: ~65% del costo de Cloud SQL al estar activa ~5.5h/día.
#
# Autenticación: oauth_token con github-actions-cicd SA (tiene roles/cloudsql.admin).
# La Cloud SQL Admin API requiere OAuth2, no OIDC — por eso se usa oauth_token.
#
# Endpoint: PATCH https://sqladmin.googleapis.com/v1/projects/{project}/instances/{instance}
#   activationPolicy: "ALWAYS" → encender
#   activationPolicy: "NEVER"  → apagar
# =============================================================================

resource "google_cloud_scheduler_job" "cloud_sql_start" {
  name      = "cloud-sql-start"
  schedule  = "0 4 * * *" # 4:00 AM Bogotá — 1h antes del login de sesión (4:30 AM)
  time_zone = var.scheduler_timezone
  project   = var.project_id
  region    = var.region

  http_target {
    uri         = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/jetex-pipeline-db"
    http_method = "PATCH"

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      settings = {
        activationPolicy = "ALWAYS"
      }
    }))

    oauth_token {
      service_account_email = google_service_account.cicd.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
    max_doublings        = 2
  }

  depends_on = [
    google_project_service.apis,
    google_sql_database_instance.pipeline,
    google_project_iam_member.cicd_roles,
    google_service_account_iam_member.cloudscheduler_act_as_cicd,
  ]
}

resource "google_cloud_scheduler_job" "cloud_sql_stop" {
  name      = "cloud-sql-stop"
  schedule  = "30 9 * * *" # 9:30 AM Bogotá — 15 min después del último scraper (8:15 AM + margen)
  time_zone = var.scheduler_timezone
  project   = var.project_id
  region    = var.region

  http_target {
    uri         = "https://sqladmin.googleapis.com/v1/projects/${var.project_id}/instances/jetex-pipeline-db"
    http_method = "PATCH"

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      settings = {
        activationPolicy = "NEVER"
      }
    }))

    oauth_token {
      service_account_email = google_service_account.cicd.email
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
    max_doublings        = 2
  }

  depends_on = [
    google_project_service.apis,
    google_sql_database_instance.pipeline,
    google_project_iam_member.cicd_roles,
    google_service_account_iam_member.cloudscheduler_act_as_cicd,
  ]
}
