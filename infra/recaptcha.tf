resource "google_recaptcha_enterprise_key" "portfolio_contact_form" {
  display_name = "carlosbustamante.dev - Contact Form"
  project      = var.gcp_project_id

  web_settings {
    integration_type  = "SCORE"
    allow_all_domains = false
    allowed_domains = [
      "carlosbustamante.dev",
      "www.carlosbustamante.dev",
      "charlyfive.com",
      "localhost"
    ]
  }

  labels = {
    environment = "production"
    purpose     = "contact-form"
  }
}

resource "google_apikeys_key" "recaptcha_assessment" {
  name         = "portfolio-recaptcha-assessment"
  display_name = "carlosbustamante.dev - reCAPTCHA Assessment"
  project      = var.gcp_project_id

  restrictions {
    api_targets {
      service = "recaptchaenterprise.googleapis.com"
    }
  }
}
