# --- Cloud SQL PostgreSQL Instance ---
#
# Conexión desde Cloud Run: via Cloud SQL Auth Proxy nativo (volumen cloud_sql_instance).
# El socket Unix queda en: /cloudsql/<connection_name>/.s.PGSQL.5432
#
# IP privada: enable_private_path_for_google_cloud_services = true permite que el
# Auth Proxy se conecte a la IP privada a través de la red interna de Google sin
# necesidad de VPC Connector en Cloud Run.
#
# Alta disponibilidad: availability_type = REGIONAL crea una réplica standby en otra zona.
# En caso de fallo zonal, Cloud SQL promueve la réplica automáticamente (failover ~60s).

resource "google_sql_database_instance" "pipeline" {
  name             = "jetex-pipeline-db"
  project          = var.project_id
  region           = var.db_region
  database_version = "POSTGRES_17"

  deletion_protection = true

  settings {
    tier              = var.db_tier
    edition           = "ENTERPRISE"
    availability_type = "REGIONAL"
    disk_size         = var.db_disk_size
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = "projects/${var.project_id}/global/networks/default"
      enable_private_path_for_google_cloud_services = true
      ssl_mode                                      = "ENCRYPTED_ONLY"
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

  # activation_policy es gestionado por los schedulers cloud-sql-start/stop.
  # Sin esto, terraform apply después de un stop resetearía la instancia a ALWAYS.
  lifecycle {
    # activation_policy: gestionado por los schedulers cloud-sql-start/stop.
    # location_preference: GCP asigna zona automáticamente al crear la instancia;
    # no está en el config, causaría recreación innecesaria si no se ignora.
    ignore_changes = [settings[0].activation_policy, settings[0].location_preference]
  }

  depends_on = [
    google_project_service.apis,
    google_service_networking_connection.private_vpc_connection,
  ]
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
