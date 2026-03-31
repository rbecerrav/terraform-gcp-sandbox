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

# --- CI/CD ---

output "cicd_sa_email" {
  description = "Email del service account de CI/CD — usar en el campo service_account del workflow de GitHub Actions"
  value       = google_service_account.cicd.email
}

output "workload_identity_provider" {
  description = "Resource name completo del WIF Provider — valor requerido en el campo workload_identity_provider del step google-github-actions/auth en el workflow"
  value       = google_iam_workload_identity_pool_provider.github_oidc.name
}

# --- Cloud Run Scrapers ---

output "scraper_service_urls" {
  description = "URLs de los 7 servicios Cloud Run scraper"
  value       = { for name, svc in google_cloud_run_v2_service.scraper : name => svc.uri }
}
