# =============================================================================
# Cloud Scheduler — Cloud SQL start / stop (cost reduction)
# =============================================================================
# Enciende Cloud SQL a las 4:00 AM (1h antes del login de sesión a las 4:30 AM)
# y la apaga a las 9:30 AM (15 min después del último scraper a las 8:15 AM).
#
# Ahorro estimado: ~77% del costo de Cloud SQL al estar activa solo ~5.5h/día.
#
# SA dedicado (cloudsql-manager-sa) con mínimos permisos — evita que cicd SA
# se impersone a sí mismo, lo que causa 403 al crear los scheduler jobs.
# =============================================================================

# Necesario para obtener el project number del agente de Cloud Scheduler
data "google_project" "project" {
  project_id = var.project_id
}

# SA dedicado con el único permiso necesario: actualizar la instancia Cloud SQL
resource "google_service_account" "cloud_sql_manager" {
  account_id   = "cloudsql-manager-sa"
  display_name = "Cloud SQL Manager"
  description  = "Used by Cloud Scheduler to start/stop the Cloud SQL instance via the Admin API."
  project      = var.project_id
}

resource "google_project_iam_member" "cloud_sql_manager_admin" {
  project = var.project_id
  role    = "roles/cloudsql.admin"
  member  = "serviceAccount:${google_service_account.cloud_sql_manager.email}"
}

# cicd SA necesita actAs sobre cloudsql-manager-sa para crear los scheduler jobs
resource "google_service_account_iam_member" "cicd_act_as_cloud_sql_manager" {
  service_account_id = google_service_account.cloud_sql_manager.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.cicd.email}"
}

# Cloud Scheduler service agent necesita actAs sobre cloudsql-manager-sa para ejecutar los jobs
resource "google_service_account_iam_member" "cloudscheduler_act_as_cloud_sql_manager" {
  service_account_id = google_service_account.cloud_sql_manager.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-cloudscheduler.iam.gserviceaccount.com"
}

resource "google_cloud_scheduler_job" "cloud_sql_start" {
  name      = "cloud-sql-start"
  schedule  = "0 4 * * *" # 4:00 AM Bogotá — 30 min antes del login de sesión (4:30 AM)
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
      service_account_email = google_service_account.cloud_sql_manager.email
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
    google_service_account_iam_member.cicd_act_as_cloud_sql_manager,
    google_service_account_iam_member.cloudscheduler_act_as_cloud_sql_manager,
  ]
}

resource "google_cloud_scheduler_job" "cloud_sql_stop" {
  name      = "cloud-sql-stop"
  schedule  = "30 9 * * *" # 9:30 AM Bogotá — 15 min después del último scraper (8:15 AM)
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
      service_account_email = google_service_account.cloud_sql_manager.email
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
    google_service_account_iam_member.cicd_act_as_cloud_sql_manager,
    google_service_account_iam_member.cloudscheduler_act_as_cloud_sql_manager,
  ]
}
