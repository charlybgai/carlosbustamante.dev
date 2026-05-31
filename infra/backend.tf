terraform {
  backend "s3" {
    bucket       = "carlosbustamante-ops-terraform-state"
    key          = "portfolio/prod/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
