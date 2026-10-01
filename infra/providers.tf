terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    # Only for google_service_usage_consumer_quota_override (recaptcha.tf), which is beta-only
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "google" {
  project               = var.gcp_project_id
  region                = "us-central1"
  billing_project       = var.gcp_project_id
  user_project_override = true
}

provider "google-beta" {
  project               = var.gcp_project_id
  region                = "us-central1"
  billing_project       = var.gcp_project_id
  user_project_override = true
}
