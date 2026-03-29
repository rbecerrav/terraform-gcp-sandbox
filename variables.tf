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

variable "session_service_image" {
  description = "Docker image for session-service-api (e.g. us-central1-docker.pkg.dev/project/repo/image:tag)"
  type        = string
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
