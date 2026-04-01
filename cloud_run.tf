# --- Cloud Run: session-service-api ---
#
# Playwright + CapSolver requieren recursos generosos:
#   - memory: 2Gi  (Chromium headless consume ~800MB base)
#   - cpu: 2       (captcha solving + JS rendering)
#   - cpu_throttling: false  (evitar timeouts durante captcha)
#
# max_instance_count: 1 — un solo browser real en ejecución a la vez.
# Cloud SQL Auth Proxy via volumen explícito (Cloud Run v2 nativo, evita drift de anotación).

resource "google_cloud_run_v2_service" "session_service" {
  name     = "session-service-api"
  location = var.region
  project  = var.project_id

  template {
    service_account = google_service_account.scraper.email

    scaling {
      min_instance_count = 0
      max_instance_count = 1
    }

    containers {
      image = var.session_service_image

      ports {
        container_port = 8080
      }

      resources {
        limits = {
          memory = "2Gi"
          cpu    = "2"
        }
        cpu_idle          = false
        startup_cpu_boost = true
      }

      # --- Categoría A: Configuración operativa (env vars directas) ---

      env {
        name  = "PAGE_LOGIN_URL"
        value = var.page_login_url
      }

      env {
        name  = "HEADLESS_MODE"
        value = "True"
      }

      env {
        name  = "TIMEZONE"
        value = var.timezone
      }

      env {
        name  = "EXPIRES_AT"
        value = tostring(var.session_expires_at)
      }

      env {
        name  = "CAPSOLVER_TASK_TYPE"
        value = var.capsolver_task_type
      }

      env {
        name  = "RECAPTCHA_SITE_KEY"
        value = var.recaptcha_site_key
      }

      # Cloud SQL Auth Proxy expone la BD via Unix socket montado en /cloudsql.
      # psycopg2 interpreta host que empieza con "/" como directorio del socket.
      # El socket queda en: /cloudsql/<connection_name>/.s.PGSQL.5432
      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      env {
        name  = "DB_HOST"
        value = "/cloudsql/${google_sql_database_instance.pipeline.connection_name}"
      }

      # DB_PORT se ignora cuando la conexión es via Unix socket, pero se mantiene
      # como fallback para desarrollo local.
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

      # --- Categoría B: Secretos inyectados desde Secret Manager ---

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

      env {
        name = "CAPSOLVER_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.capsolver_api_key.secret_id
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
    google_secret_manager_secret_iam_member.scraper_capsolver_api_key,
  ]
}
