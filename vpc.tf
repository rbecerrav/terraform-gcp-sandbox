# --- VPC Custom: jetex-pipeline ---
#
# VPC dedicada para el proyecto — aislada de la VPC default del proyecto.
# Evita compartir blast radius con otros servicios y permite control total
# sobre las reglas de firewall y los rangos IP.

resource "google_compute_network" "pipeline" {
  name                    = "jetex-pipeline-vpc"
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"

  depends_on = [google_project_service.apis]
}

# Subnet principal en la misma región que Cloud SQL y Cloud Run.
# private_ip_google_access = true permite que la bastion VM acceda a APIs
# de Google (Secret Manager, Cloud SQL Admin) sin necesitar IP pública.
resource "google_compute_subnetwork" "pipeline" {
  name          = "jetex-pipeline-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.pipeline.id
  ip_cidr_range = "10.10.0.0/24"

  private_ip_google_access = true
}

# Subnet dedicada para el VPC connector (debe ser exactamente /28).
# private_ip_google_access = true permite que el tráfico del conector
# alcance Google APIs (sqladmin, secretmanager, etc.) via Private Google
# Access sin salir a internet — necesario para Cloud SQL Auth Proxy
# cuando egress = ALL_TRAFFIC.
resource "google_compute_subnetwork" "vpc_connector" {
  name          = "jetex-connector-subnet"
  project       = var.project_id
  region        = var.region
  network       = google_compute_network.pipeline.id
  ip_cidr_range = "10.10.1.0/28"

  private_ip_google_access = true
}

# --- Private Service Access para Cloud SQL ---
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
  network       = google_compute_network.pipeline.id

  depends_on = [google_project_service.apis]
}

# Conexión de peering entre la VPC custom y los servicios de Google.
# Permite que Cloud SQL tenga una IP privada dentro del rango reservado.
resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.pipeline.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  depends_on = [google_project_service.apis]
}
