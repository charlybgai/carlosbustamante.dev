variable "gcp_project_id" {
  description = "GCP project ID for reCAPTCHA Enterprise"
  type        = string
}

variable "project_name" {
  description = "Project name for tagging"
  type        = string
  default     = "carlosbustamante-portfolio"
}

variable "root_domain" {
  description = "The main domain name"
  type        = string
}

variable "certificate_arn" {
  description = "ACM Certificate ARN for CloudFront"
  type        = string
}

variable "www_certificate_arn" {
  description = "ACM Certificate ARN for the www redirect CloudFront distribution"
  type        = string
  default     = null
}

variable "contact_sender_email" {
  description = "Email address SES uses as the source for contact form messages"
  type        = string
  default     = "me@carlosbustamante.dev"
}

variable "contact_recipient_email" {
  description = "Email address that receives contact form messages"
  type        = string
  default     = "me@carlosbustamante.dev"
}

variable "alert_email" {
  description = "Email address for contact form alerts (defaults to contact_recipient_email)"
  type        = string
  default     = null
}

variable "recaptcha_daily_assessment_cap" {
  description = "Most reCAPTCHA assessments the project may create per day. 300/day keeps a month under the 10,000 free assessments."
  type        = number
  default     = 300
}

variable "subdomains" {
  description = "Map of subdomains to create"
  type        = map(string)
  default     = {}
}
