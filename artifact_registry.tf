# --- Artifact Registry: Docker images ---

resource "google_artifact_registry_repository" "docker" {
  repository_id = "docker-images"
  location      = "us-central1" # Fijo — independiente de var.region para no perder imágenes al cambiar la región de Cloud Run
  format        = "DOCKER"
  description   = "Docker images for Cloud Run services"
  project       = var.project_id

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s" # 30 dias
    }
  }

  cleanup_policies {
    id     = "keep-recent-tagged"
    action = "KEEP"
    most_recent_versions {
      keep_count = 10
    }
  }

  depends_on = [google_project_service.apis]
}
