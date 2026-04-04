# --- VPC: Private Service Access para Cloud SQL ---
#
# Permite que Cloud SQL use una IP privada en lugar de IP pública.
# Cloud Run accede a Cloud SQL via Cloud SQL Auth Proxy con private path habilitado
# (enable_private_path_for_google_cloud_services = true en cloud_sql.tf),
# lo que enruta la conexión a través de la red interna de Google sin necesidad
# de VPC connector adicional.
#
# Flujo de conexión:
#   Cloud Run → Cloud SQL Auth Proxy (via internal Google network) → Cloud SQL (IP privada)

# Rango de IPs privadas reservado para peering con servicios de Google.
# Este bloque no crea subnets — solo reserva el rango para el peering.
resource "google_compute_global_address" "private_ip_range" {
  name          = "cloudsql-private-ip-range"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = "projects/${var.project_id}/global/networks/default"

  depends_on = [google_project_service.apis]
}

# Conexión de peering entre el VPC default y los servicios de Google.
# Permite que Cloud SQL tenga una IP privada dentro del rango reservado.
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = "projects/${var.project_id}/global/networks/default"
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_project_service.apis]
}
