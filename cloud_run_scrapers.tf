# --- Cloud Run: 7 scrapers via for_each ---
#
# Todos los scrapers son ligeros (sin Playwright):
#   - memory: 512Mi
#   - cpu: 1
#   - cpu_idle: true  (solo necesitan CPU durante la ejecución del ETL)
#
# Dependen de session-service-api para obtener tokens de sesión.
# Cloud SQL Auth Proxy via volumen explícito (Cloud Run v2 nativo, evita drift de anotación).

resource "google_cloud_run_v2_service" "scraper" {
  for_each = var.scraper_services

  name     = each.key
  location = var.region
  project  = var.project_id
  ingress  = "INGRESS_TRAFFIC_INTERNAL_ONLY"

  template {
    service_account = google_service_account.scraper.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      # Imagen derivada automáticamente: el nombre del servicio (each.key) coincide con el nombre de la imagen en Artifact Registry
      image = "us-central1-docker.pkg.dev/${var.project_id}/docker-images/${each.key}:${local.image_tags[each.key]}"

      ports {
        container_port = each.value.container_port
      }

      resources {
        limits = {
          memory = each.value.memory
          cpu    = each.value.cpu
        }
        cpu_idle          = true
        startup_cpu_boost = true
      }

      # APP_PORT debe coincidir con container_port para evitar PORT mismatch en Cloud Run
      env {
        name  = "APP_PORT"
        value = tostring(each.value.container_port)
      }

      env {
        name  = "TIMEZONE"
        value = var.timezone
      }

      env {
        name  = "STORED_PROCEDURE_NAME"
        value = each.value.stored_procedure_name
      }

      env {
        name  = "SESSION_BASE_URL"
        value = google_cloud_run_v2_service.session_service.uri
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "DB_HOST"
        value = "/cloudsql/${google_sql_database_instance.pipeline.connection_name}"
      }

      env {
        name  = "DB_PORT"
        value = "5432"
      }

      env {
        name  = "DB_SCHEMA"
        value = var.db_schema
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }

      env {
        name = "DB_NAME"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_name.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DB_USER"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_user.secret_id
            version = "latest"
          }
        }
      }

      env {
        name = "DB_PASSWORD"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_password.secret_id
            version = "latest"
          }
        }
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.pipeline.connection_name]
      }
    }
  }

  depends_on = [
    google_project_service.apis,
    google_secret_manager_secret_iam_member.scraper_db_name,
    google_secret_manager_secret_iam_member.scraper_db_user,
    google_secret_manager_secret_iam_member.scraper_db_password,
    google_cloud_run_v2_service.session_service,
  ]
}
