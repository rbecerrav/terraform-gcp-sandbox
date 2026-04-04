variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "Default GCP region — debe coincidir con db_region para que enable_private_path_for_google_cloud_services funcione desde Cloud Run sin VPC connector"
  type        = string
  default     = "us-east4"
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
  default     = "db-custom-1-3840" # para prod db-custom-2-8192
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
# Una variable por servicio — cada una vive en su propio *.auto.tfvars.
# El workflow _docker-publish.yml actualiza solo el archivo del servicio desplegado.
# Sin conflictos de merge: cada PR de GitOps toca un único archivo independiente.

variable "image_tag_accounting_fuel_savings" {
  description = "Image tag para accounting-fuel-savings. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_accounting_invoice" {
  description = "Image tag para accounting-invoice. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_aircraft_discrepancies" {
  description = "Image tag para aircraft-discrepancies. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_aircraft_logged_flights" {
  description = "Image tag para aircraft-logged-flights. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_aircraft_utilization" {
  description = "Image tag para aircraft-utilization. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_sales_productivity" {
  description = "Image tag para sales-productivity. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_trip_finances" {
  description = "Image tag para trip-finances. Actualizado por GitOps."
  type        = string
  default     = "latest"
}

variable "image_tag_session_service_api" {
  description = "Image tag para session-service-api. Actualizado por GitOps."
  type        = string
  default     = "latest"
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
  description = "Cron for company-1 session login (JetExcellence). 4:30 AM Bogota — 30 min before first scraper."
  type        = string
  default     = "30 4 * * *"
}

variable "scheduler_login_cron_company2" {
  description = "Cron for company-2 session login (FlyBelair). 4:35 AM Bogota — 5 min after company-1 to avoid simultaneous logins."
  type        = string
  default     = "35 4 * * *"
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
