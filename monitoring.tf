# =============================================================================
# Cloud Monitoring — Alertas de producción
# =============================================================================
# Cubre los 4 indicadores clave del pipeline:
#   1. Fallos de Cloud Scheduler (jobs de login y ETL)
#   2. Tasa de errores 5xx en Cloud Run
#   3. Conexiones activas en Cloud SQL > 80%
#   4. Errores de autenticación IAM (403/401) en Cloud Run
#
# Todas las alertas notifican al canal de email configurado en var.alert_email.
# =============================================================================

# --- Canal de notificación: email ---

resource "google_monitoring_notification_channel" "email" {
  display_name = "Ops Email"
  type         = "email"
  project      = var.project_id

  labels = {
    email_address = var.alert_email
  }

  depends_on = [google_project_service.apis]
}

# =============================================================================
# 1. Cloud Scheduler — fallos después de agotar reintentos
# =============================================================================
# Métrica log-based: cuenta errores en logs de Cloud Scheduler.
# Un job falla silenciosamente si no hay alerta — el pipeline queda sin sesión
# o sin datos ETL hasta la siguiente ejecución programada.

resource "google_logging_metric" "scheduler_job_failed" {
  name    = "cloudscheduler_job_failed"
  project = var.project_id

  filter = <<-EOT
    resource.type="cloud_scheduler_job"
    severity>=ERROR
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "job_id"
      value_type  = "STRING"
      description = "Nombre del Cloud Scheduler job"
    }
  }

  label_extractors = {
    "job_id" = "EXTRACT(resource.labels.job_id)"
  }

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "scheduler_job_failed" {
  display_name = "Cloud Scheduler — Job fallido"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Al menos 1 fallo de Scheduler en 10 minutos"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.scheduler_job_failed.name}\" resource.type=\"cloud_scheduler_job\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0

      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "86400s" # Cierra la alerta si no hay nuevos datos en 24h
  }

  documentation {
    content   = "Un Cloud Scheduler job falló después de agotar sus reintentos. Verificar logs en Cloud Logging filtrando por `resource.type=\"cloud_scheduler_job\"`."
    mime_type = "text/markdown"
  }

  depends_on = [google_logging_metric.scheduler_job_failed]
}

# =============================================================================
# 2. Cloud Run — tasa de errores 5xx > 5%
# =============================================================================
# Alerta cuando más del 5% de las requests a cualquier servicio Cloud Run
# retornan un error del servidor (5xx). Indica fallos en la lógica del scraper
# o problemas de conectividad con Cloud SQL / Session Service.

resource "google_monitoring_alert_policy" "cloud_run_5xx" {
  display_name = "Cloud Run — Tasa de errores 5xx > 5%"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "5xx rate supera el 5% en ventana de 5 minutos"

    condition_threshold {
      filter          = "metric.type=\"run.googleapis.com/request_count\" resource.type=\"cloud_run_revision\" metric.label.response_code_class=\"5xx\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period     = "300s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
        group_by_fields      = ["resource.label.service_name"]
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "86400s"
  }

  documentation {
    content   = "Un servicio Cloud Run está retornando errores 5xx por encima del umbral. Revisar logs del servicio afectado en Cloud Logging."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.apis]
}

# =============================================================================
# 3. Cloud SQL — conexiones activas > 80% del máximo
# =============================================================================
# Para db-custom-2-8192 (2 vCPU, 8GB RAM), PostgreSQL 17 configura
# max_connections ≈ 200 por defecto en Cloud SQL.
# Umbral: 160 conexiones (80% de 200).
# Si se supera, el pipeline empezará a rechazar nuevas conexiones.

resource "google_monitoring_alert_policy" "cloud_sql_connections" {
  display_name = "Cloud SQL — Conexiones activas > 80%"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Conexiones PostgreSQL superan 160 (80% de max_connections=200)"

    condition_threshold {
      filter          = "metric.type=\"cloudsql.googleapis.com/database/postgresql/num_backends\" resource.type=\"cloudsql_database\""
      duration        = "300s"
      comparison      = "COMPARISON_GT"
      threshold_value = 160

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "86400s"
  }

  documentation {
    content   = "Cloud SQL está cerca del límite de conexiones. Verificar si hay conexiones abiertas sin cerrar en los scrapers. Revisar el pool de SQLAlchemy en `database_connection.py`."
    mime_type = "text/markdown"
  }

  depends_on = [google_project_service.apis]
}

# =============================================================================
# 4. Cloud Run — errores de autorización IAM (403)
# =============================================================================
# Detecta errores de autenticación que pueden indicar:
#   - SA con permisos revocados
#   - Token OIDC expirado o mal configurado
#   - Acceso no autorizado al endpoint

resource "google_logging_metric" "cloud_run_auth_errors" {
  name    = "cloud_run_auth_errors"
  project = var.project_id

  filter = <<-EOT
    resource.type="cloud_run_revision"
    httpRequest.status=403
  EOT

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    labels {
      key         = "service_name"
      value_type  = "STRING"
      description = "Nombre del servicio Cloud Run"
    }
  }

  label_extractors = {
    "service_name" = "EXTRACT(resource.labels.service_name)"
  }

  depends_on = [google_project_service.apis]
}

resource "google_monitoring_alert_policy" "cloud_run_auth_errors" {
  display_name = "Cloud Run — Errores de autorización IAM (403)"
  project      = var.project_id
  combiner     = "OR"

  conditions {
    display_name = "Más de 5 errores 403 en 10 minutos"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.cloud_run_auth_errors.name}\" resource.type=\"cloud_run_revision\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 5

      aggregations {
        alignment_period   = "600s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.email.id]

  alert_strategy {
    auto_close = "86400s"
  }

  documentation {
    content   = "Se detectaron múltiples errores 403 en Cloud Run. Posible causa: SA sin permisos, OIDC token inválido o intento de acceso no autorizado. Revisar IAM bindings y logs de Cloud Run."
    mime_type = "text/markdown"
  }

  depends_on = [google_logging_metric.cloud_run_auth_errors]
}
