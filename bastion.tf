# --- Bastion VM para acceso local a Cloud SQL ---
#
# VM mínima (e2-micro, free tier) usada exclusivamente para tunelizar
# conexiones locales a Cloud SQL via Cloud SQL Auth Proxy.
#
# Flujo de conexión local:
#   DBeaver (localhost:5432)
#     → gcloud compute ssh bastion --tunnel-through-iap -- -L 5432:127.0.0.1:5432 -N
#       → Cloud SQL Auth Proxy corriendo en la VM
#         → Cloud SQL IP privada
#
# SSH se expone únicamente via IAP (Identity-Aware Proxy) — sin puerto 22 abierto
# a internet. El firewall solo permite ingreso desde el rango de IAP (35.235.240.0/20).

resource "google_service_account" "bastion" {
  account_id   = "bastion-sa"
  display_name = "Bastion Service Account"
  description  = "Used by the bastion VM to run Cloud SQL Auth Proxy"
  project      = var.project_id
}

resource "google_project_iam_member" "bastion_cloudsql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.bastion.email}"
}

# Firewall: permite SSH solo desde Google IAP (no expone puerto 22 al internet)
resource "google_compute_firewall" "allow_iap_ssh" {
  name    = "allow-iap-ssh-bastion"
  project = var.project_id
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  # Rango de IPs de Google IAP TCP forwarding
  source_ranges = ["35.235.240.0/20"]
  target_tags   = ["bastion"]
}

resource "google_compute_instance" "bastion" {
  name         = "sql-bastion"
  machine_type = "e2-micro"
  zone         = "${var.db_region}-b"
  project      = var.project_id

  tags = ["bastion"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 10
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    # Sin access_config → sin IP pública
  }

  service_account {
    email  = google_service_account.bastion.email
    scopes = ["cloud-platform"]
  }

  # Instala Cloud SQL Auth Proxy al arrancar
  metadata_startup_script = <<-EOT
    #!/bin/bash
    curl -fsSL -o /usr/local/bin/cloud-sql-proxy \
      https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.3/cloud-sql-proxy.linux.amd64
    chmod +x /usr/local/bin/cloud-sql-proxy
  EOT

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  depends_on = [
    google_project_service.apis,
    google_project_iam_member.bastion_cloudsql,
  ]
}
