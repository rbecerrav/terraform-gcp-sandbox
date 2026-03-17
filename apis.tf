resource "google_project_service" "apis" {
  for_each = toset([
    "compute.googleapis.com",           # VMs, redes, discos
    "storage.googleapis.com",           # Cloud Storage buckets
    "iam.googleapis.com",               # IAM roles y service accounts
    "iamcredentials.googleapis.com",    # Workload Identity Federation
    "cloudresourcemanager.googleapis.com", # Gestión del proyecto
    "run.googleapis.com",               # Cloud Run
    "cloudfunctions.googleapis.com",    # Cloud Functions
    "sqladmin.googleapis.com",          # Cloud SQL
    "container.googleapis.com",         # GKE
    "dns.googleapis.com",               # Cloud DNS
    "secretmanager.googleapis.com",     # Secret Manager
    "monitoring.googleapis.com",        # Cloud Monitoring
    "logging.googleapis.com",           # Cloud Logging
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false # No deshabilitar la API si se destruye el recurso
}
