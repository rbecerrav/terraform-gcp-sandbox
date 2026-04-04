resource "google_project_service" "apis" {
  for_each = toset([
    "storage.googleapis.com",              # Cloud Storage buckets (tfstate)
    "iam.googleapis.com",                  # IAM roles y service accounts
    "iamcredentials.googleapis.com",       # Workload Identity Federation
    "cloudresourcemanager.googleapis.com", # Gestión del proyecto
    "run.googleapis.com",                  # Cloud Run
    "sqladmin.googleapis.com",             # Cloud SQL
    "secretmanager.googleapis.com",        # Secret Manager
    "monitoring.googleapis.com",           # Cloud Monitoring
    "logging.googleapis.com",              # Cloud Logging
    "cloudscheduler.googleapis.com",       # Cloud Scheduler
    "sts.googleapis.com",                  # Security Token Service — requerido por Workload Identity Federation
    "compute.googleapis.com",              # VPC networking — requerido para Private Service Access de Cloud SQL
    "servicenetworking.googleapis.com",    # Private Service Access — peering entre VPC y servicios de Google
    "iap.googleapis.com",                  # Identity-Aware Proxy — SSH tunneling al bastion sin IP pública
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false # No deshabilitar la API al destruir — evita romper otros servicios del proyecto
}
