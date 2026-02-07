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

variable "subdomains" {
  description = "Map of subdomains to create"
  type        = map(string)
  default     = {}
}
