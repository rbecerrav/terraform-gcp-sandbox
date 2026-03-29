# --- Secret Manager: Database connection details ---
#
# db-connection-name es el valor clave: el scraper lo usa para configurar
# el Cloud SQL Auth Proxy socket. Formato: project:region:instance
# Los scrapers leen estos secretos al iniciar via GCP Secret Manager SDK.

resource "google_secret_manager_secret" "db_connection_name" {
  secret_id = "db-connection-name"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_connection_name" {
  secret      = google_secret_manager_secret.db_connection_name.id
  secret_data = google_sql_database_instance.pipeline.connection_name
}

resource "google_secret_manager_secret" "db_name" {
  secret_id = "db-name"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_name" {
  secret      = google_secret_manager_secret.db_name.id
  secret_data = var.db_name
}

resource "google_secret_manager_secret" "db_user" {
  secret_id = "db-user"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_user" {
  secret      = google_secret_manager_secret.db_user.id
  secret_data = var.db_user
}

resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

# --- Secret Manager: CapSolver API Key (Externally-managed) ---
#
# Terraform crea SOLO el contenedor del secreto.
# El VALOR se carga manualmente fuera de Terraform (nunca en tfstate):
#
#   echo -n "<CAPSOLVER_API_KEY>" | gcloud secrets versions add capsolver-api-key \
#     --data-file=- --project=<PROJECT_ID>
#
# Verificar: gcloud secrets versions list capsolver-api-key --project=<PROJECT_ID>

resource "google_secret_manager_secret" "capsolver_api_key" {
  secret_id = "capsolver-api-key"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

# --- Secret Manager: Credenciales de portales (Externally-managed) ---
#
# Terraform crea SOLO el contenedor. Los VALORES se cargan manualmente:
#
#   echo -n "<VALOR>" | gcloud secrets versions add <nombre> \
#     --data-file=- --project=<PROJECT_ID>

resource "google_secret_manager_secret" "jet_exc_email" {
  secret_id = "jet-exc-email"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "jet_exc_password" {
  secret_id = "jet-exc-password"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "fly_belair_email" {
  secret_id = "fly-belair-email"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}

resource "google_secret_manager_secret" "fly_belair_password" {
  secret_id = "fly-belair-password"
  project   = var.project_id

  replication {
    auto {}
  }

  depends_on = [google_project_service.apis]
}
