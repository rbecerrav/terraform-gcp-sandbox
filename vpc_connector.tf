# --- Serverless VPC Access Connector ---
#
# Permite que Cloud Run se conecte a recursos dentro del VPC (incluido Cloud SQL
# con IP privada via Private Service Access) sin necesidad de IP pública.
#
# enable_private_path_for_google_cloud_services no funciona de forma confiable
# cuando el VPC tiene Private Service Access activo — el connector es el método
# recomendado y battle-tested para este escenario.
#
# Costo estimado: ~$0 adicional en f1-micro con min_instances=2 dentro del free tier
# de Serverless VPC Access (~720 hrs/mes de instancia incluidas).

resource "google_vpc_access_connector" "cloud_run" {
  name    = "cloud-run-connector"
  region  = var.region
  project = var.project_id

  # Usa la subnet dedicada de la VPC custom en lugar de ip_cidr_range.
  # jetex-pipeline-subnet tiene private_ip_google_access = true, lo que permite
  # que las llamadas a Google APIs (sqladmin.googleapis.com, secretmanager, etc.)
  # vayan por Private Google Access sin salir a internet — requerido para que
  # el Cloud SQL Auth Proxy funcione con egress = ALL_TRAFFIC.
  subnet {
    name       = google_compute_subnetwork.vpc_connector.name
    project_id = var.project_id
  }

  min_instances = 2
  max_instances = 3
  machine_type  = "f1-micro"

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.cicd_roles,
    google_compute_subnetwork.vpc_connector,
  ]
}
