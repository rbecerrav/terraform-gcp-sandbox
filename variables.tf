variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region"
  type        = string
  default     = "us-central1"
}

# --- Cloud SQL ---

variable "db_region" {
  description = "Region for Cloud SQL instance"
  type        = string
  default     = "us-east4"
}

variable "db_tier" {
  description = "Cloud SQL machine tier"
  type        = string
  default     = "db-custom-2-8192"
}

variable "db_disk_size" {
  description = "Initial disk size in GB for Cloud SQL"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Name of the PostgreSQL database"
  type        = string
  default     = "jetex_pipeline"
}

variable "db_user" {
  description = "Database user for scraper services"
  type        = string
  default     = "pipeline_writer"
}

# --- Cloud Run ---

# --- Monitoring ---

variable "alert_email" {
  description = "Email address for Cloud Monitoring alert notifications (ops/on-call inbox)."
  type        = string
}

# --- Image tags (GitOps) ---
#
# Gestionado automáticamente por el workflow _docker-publish.yml del repo de servicios.
# Cada merge a main en el repo de servicios abre un PR aquí actualizando el tag del servicio afectado.
# No modificar manualmente — los cambios serán sobreescritos por el workflow.
# Para desarrollo local, terraform usa el default "latest" definido en cada key.

variable "image_tags" {
  description = "Docker image tag por servicio. Actualizado automáticamente via GitOps desde Fraktal-JetExcellence-Scrappers."
  type        = map(string)
  default = {
    "accounting-fuel-savings" = "latest"
    "accounting-invoice"      = "latest"
    "aircraft-discrepancies"  = "latest"
    "aircraft-logged-flights" = "latest"
    "aircraft-utilization"    = "latest"
    "sales-productivity"      = "latest"
    "trip-finances"           = "latest"
    "session-service-api"     = "latest"
  }
}

variable "timezone" {
  description = "Application timezone"
  type        = string
  default     = "America/Bogota"
}

variable "session_expires_at" {
  description = "Session expiry in hours"
  type        = number
  default     = 6
}

variable "db_schema" {
  description = "Database schema name"
  type        = string
  default     = "staging"
}

variable "recaptcha_site_key" {
  description = "reCAPTCHA v2 site key for JetInsight portal (public, visible in HTML)"
  type        = string
  default     = "6Lc8aLMaAAAAAM-7v5CE93Y_X_UMNHTgw9UwY57Z"
}

variable "page_login_url" {
  description = "JetInsight portal login URL"
  type        = string
  default     = "https://portal.jetinsight.com/users/sign_in"
}

variable "capsolver_task_type" {
  description = "CapSolver task type for reCAPTCHA solving"
  type        = string
  default     = "ReCaptchaV2TaskProxyLess"
}

# --- CI/CD ---

variable "github_repo" {
  description = "GitHub repository in 'org/repo' format. Used to restrict Workload Identity Federation to this specific repo."
  type        = string
  default     = "FraktalSoftware/Fraktal-JetExcellence-Scrappers"
}

# --- Cloud Scheduler ---

variable "scheduler_timezone" {
  description = "Timezone for Cloud Scheduler jobs"
  type        = string
  default     = "America/Bogota"
}

variable "scheduler_login_cron" {
  description = "Cron schedule for session login jobs (default: every 5 hours)"
  type        = string
  default     = "0 */5 * * *"
}

variable "scraper_scheduler_cron" {
  description = "Cron schedule for scraper ETL jobs (default: daily at 6am Bogota time)"
  type        = string
  default     = "0 6 * * *"
}

# --- Scraper services map ---

variable "scraper_services" {
  description = "Map of scraper services to deploy on Cloud Run. Image is derived automatically from project_id and service name."
  type = map(object({
    container_port        = number
    stored_procedure_name = string
    endpoint_path         = string
    schedule_order        = number # 0–6: determina el slot de inicio (5am + order*30min para c1, +15min para c2)
    cpu                   = optional(string, "1")
    memory                = optional(string, "512Mi")
  }))
  default = {
    accounting-fuel-savings = {
      container_port        = 8081
      stored_procedure_name = "staging.sp_etl_load_fuel_purchases"
      endpoint_path         = "/api/v1/accounting-fuel-savings/execution"
      schedule_order        = 0 # company-1: 5:00 | company-2: 5:15
    }
    accounting-invoice = {
      container_port        = 8082
      stored_procedure_name = "staging.sp_etl_load_invoices"
      endpoint_path         = "/api/v1/accounting-invoice/execution"
      schedule_order        = 1 # company-1: 5:30 | company-2: 5:45
    }
    aircraft-discrepancies = {
      container_port        = 8083
      stored_procedure_name = "staging.sp_etl_load_discrepancies"
      endpoint_path         = "/api/v1/aircraft-discrepancies/execution"
      schedule_order        = 2 # company-1: 6:00 | company-2: 6:15
    }
    aircraft-logged-flights = {
      container_port        = 8084
      stored_procedure_name = "staging.sp_etl_load_flight_segments"
      endpoint_path         = "/api/v1/aircraft-logged-flights/execution"
      schedule_order        = 3 # company-1: 6:30 | company-2: 6:45
    }
    aircraft-utilization = {
      container_port        = 8085
      stored_procedure_name = "staging.sp_etl_load_utilization"
      endpoint_path         = "/api/v1/aircraft-utilization/execution"
      schedule_order        = 4 # company-1: 7:00 | company-2: 7:15
    }
    sales-productivity = {
      container_port        = 8086
      stored_procedure_name = "staging.sp_etl_load_sales_productivity"
      endpoint_path         = "/api/v1/sales-productivity/execution"
      schedule_order        = 5 # company-1: 7:30 | company-2: 7:45
    }
    trip-finances = {
      container_port        = 8087
      stored_procedure_name = "staging.sp_process_trip_finances"
      endpoint_path         = "/api/v1/trip-finances/execution"
      schedule_order        = 6 # company-1: 8:00 | company-2: 8:15
    }
  }
}
