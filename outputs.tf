output "project_id" {
  description = "GCP Project ID in use"
  value       = var.project_id
}

# --- Cloud SQL ---

output "db_connection_name" {
  description = "Cloud SQL connection name — usar en la anotacion run.googleapis.com/cloudsql-instances del servicio Cloud Run"
  value       = google_sql_database_instance.pipeline.connection_name
}

output "db_instance_name" {
  description = "Cloud SQL instance name"
  value       = google_sql_database_instance.pipeline.name
}

# --- Service Accounts ---

output "scraper_sa_email" {
  description = "Email del service account para los scrapers (asignar en Cloud Run)"
  value       = google_service_account.scraper.email
}

output "api_sa_email" {
  description = "Email del service account para el API backend (asignar en Cloud Run)"
  value       = google_service_account.api.email
}

# --- Cloud Run ---

output "session_service_url" {
  description = "URL del servicio Cloud Run session-service-api"
  value       = google_cloud_run_v2_service.session_service.uri
}

# --- Artifact Registry ---

output "artifact_registry_url" {
  description = "URL base del repositorio Docker en Artifact Registry"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.docker.repository_id}"
}
