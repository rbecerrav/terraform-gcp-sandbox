# --- Artifact Registry: Docker images ---

resource "google_artifact_registry_repository" "docker" {
  repository_id = "docker-images"
  location      = var.region
  format        = "DOCKER"
  description   = "Docker images for Cloud Run services"
  project       = var.project_id

  depends_on = [google_project_service.apis]
}
