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

# Daily cap on CreateAssessment calls (the default is unlimited). Google bills every assessment,
# junk tokens included, and the Lambda can't tell a bot from a person before asking Google.
# 300/day is far above real traffic and keeps a month under the 10,000 free assessments.
# Past the cap Google answers 429, the Lambda returns 503 and the contact-api-5xx alarm fires.
resource "google_service_usage_consumer_quota_override" "recaptcha_assessments_per_day" {
  provider       = google-beta
  project        = var.gcp_project_id
  service        = "recaptchaenterprise.googleapis.com"
  metric         = urlencode("recaptchaenterprise.googleapis.com/CreateAssessmentRequests")
  limit          = urlencode("/d/project")
  override_value = tostring(var.recaptcha_daily_assessment_cap)
  # Required because lowering a quota by more than 10% (here: from unlimited) is otherwise refused
  force = true
}
