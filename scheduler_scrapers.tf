# --- Cloud Scheduler: 14 jobs (2 por scraper — company 1 y company 2) ---
#
# Genera dinámicamente las 14 combinaciones svc x company desde un locals.
# El body incluye start_date/end_date vacíos; el servicio los interpreta como
# "rango completo" o "desde la última ejecución" según su lógica interna.
#
# Autenticación: OIDC token de scraper-sa — Cloud Run valida automáticamente.

# Calcula el cron para cada job a partir de schedule_order:
#   company-1: 5:00 + (order * 30 min)
#   company-2: 5:00 + (order * 30 + 15 min)
#
# Resultado (America/Bogota):
#   accounting-fuel-savings  → c1: 5:00  c2: 5:15
#   accounting-invoice       → c1: 5:30  c2: 5:45
#   aircraft-discrepancies   → c1: 6:00  c2: 6:15
#   aircraft-logged-flights  → c1: 6:30  c2: 6:45
#   aircraft-utilization     → c1: 7:00  c2: 7:15
#   sales-productivity       → c1: 7:30  c2: 7:45
#   trip-finances            → c1: 8:00  c2: 8:15

locals {
  scraper_scheduler_jobs = merge([
    for svc_name, svc in var.scraper_services : {
      "${svc_name}-company-1" = {
        service    = svc_name
        company_id = "1"
        endpoint   = svc.endpoint_path
        cron       = "${(5 * 60 + svc.schedule_order * 30) % 60} ${floor((5 * 60 + svc.schedule_order * 30) / 60)} * * *"
      }
      "${svc_name}-company-2" = {
        service    = svc_name
        company_id = "2"
        endpoint   = svc.endpoint_path
        cron       = "${(5 * 60 + svc.schedule_order * 30 + 15) % 60} ${floor((5 * 60 + svc.schedule_order * 30 + 15) / 60)} * * *"
      }
    }
  ]...)
}

resource "google_cloud_scheduler_job" "scraper" {
  for_each = local.scraper_scheduler_jobs

  name      = each.key
  schedule  = each.value.cron
  time_zone = var.scheduler_timezone
  project   = var.project_id
  region    = var.region

  http_target {
    uri         = "${google_cloud_run_v2_service.scraper[each.value.service].uri}${each.value.endpoint}"
    http_method = "POST"

    headers = {
      "Content-Type" = "application/json"
    }

    body = base64encode(jsonencode({
      start_date = ""
      end_date   = ""
      company_id = each.value.company_id
    }))

    oidc_token {
      service_account_email = google_service_account.scraper.email
      audience              = google_cloud_run_v2_service.scraper[each.value.service].uri
    }
  }

  retry_config {
    retry_count          = 3
    min_backoff_duration = "120s"
    max_backoff_duration = "400s"
    max_doublings        = 3
    max_retry_duration   = "1500s" # 25 minutos — slot de 30min menos margen
  }

  depends_on = [
    google_project_service.apis,
    google_cloud_run_v2_service.scraper,
    google_cloud_run_v2_service_iam_member.scraper_invoker_scrapers,
  ]
}

# --- IAM: scraper-sa puede invocar cada Cloud Run scraper (para OIDC de Scheduler) ---

resource "google_cloud_run_v2_service_iam_member" "scraper_invoker_scrapers" {
  for_each = var.scraper_services

  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.scraper[each.key].name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.scraper.email}"
}
