terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  backend "gcs" {
    bucket = "tfstate-7ceba286-c3bb-4d79"
    prefix = "bucket-state"
  }
}
