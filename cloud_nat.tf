# --- Cloud NAT ---
#
# Permite que los scrapers (egress ALL_TRAFFIC via VPC connector) accedan a internet
# para llamar al portal JetInsight, mientras el tráfico interno (session-service-api)
# se enruta dentro del VPC sin salir a internet.
#
# Cloud NAT asigna IPs de salida automáticamente — no se reservan IPs estáticas
# para mantener el costo mínimo.
#
# Costo estimado: ~$1.03/gateway/mes + $0.045/GB procesado.

resource "google_compute_router" "nat_router" {
  name    = "cloud-nat-router"
  project = var.project_id
  region  = var.region
  network = "default"

  depends_on = [google_project_service.apis]
}

resource "google_compute_router_nat" "cloud_nat" {
  name                               = "cloud-nat"
  project                            = var.project_id
  region                             = var.region
  router                             = google_compute_router.nat_router.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }

  depends_on = [google_project_service.apis]
}
