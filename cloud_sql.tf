# --- Cloud SQL PostgreSQL Instance ---
#
# Conexion desde Cloud Run: via Cloud SQL Auth Proxy nativo.
# El servicio de Cloud Run debe tener la anotacion:
#   run.googleapis.com/cloudsql-instances = <connection_name>
# El scraper se conecta al socket Unix: /cloudsql/<connection_name>
# No se requiere VPC Connector.

resource "google_sql_database_instance" "pipeline" {
  name             = "jetex-pipeline-db"
  project          = var.project_id
  region           = var.db_region
  database_version = "POSTGRES_17"

  deletion_protection = true

  settings {
    tier              = var.db_tier
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_size         = var.db_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled = true
      ssl_mode     = "ENCRYPTED_ONLY"
      # Sin authorized_networks: ninguna IP puede conectarse directamente.
      # Solo el Cloud SQL Auth Proxy (via IAM) puede autenticarse.
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      start_time                     = "04:00"
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
      }
    }

    maintenance_window {
      day          = 7 # Sunday
      hour         = 4 # 4 AM UTC
      update_track = "stable"
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
  }

  depends_on = [google_project_service.apis]
}

# --- Database ---

resource "google_sql_database" "pipeline" {
  name     = var.db_name
  project  = var.project_id
  instance = google_sql_database_instance.pipeline.name
}

# --- Database User ---

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_sql_user" "pipeline_writer" {
  name     = var.db_user
  project  = var.project_id
  instance = google_sql_database_instance.pipeline.name
  password = random_password.db_password.result
}
