# This configuration owns only the existing state bucket's policy and lifecycle.
# Its separate local state never reads or imports the site's state contents.
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_s3_bucket" "state" {
  bucket = "carlosbustamante-ops-terraform-state"
}

resource "aws_s3_bucket_policy" "state" {
  bucket = data.aws_s3_bucket.state.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "DenyInsecureTransport"
      Effect    = "Deny"
      Principal = "*"
      Action    = "s3:*"
      Resource  = [data.aws_s3_bucket.state.arn, "${data.aws_s3_bucket.state.arn}/*"]
      Condition = { Bool = { "aws:SecureTransport" = "false" } }
    }]
  })
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = data.aws_s3_bucket.state.id

  rule {
    id     = "retain-state-history"
    status = "Enabled"
    filter {
      prefix = "portfolio/"
    }
    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 10
    }
  }
  rule {
    id     = "remove-expired-delete-markers"
    status = "Enabled"
    filter {
      prefix = "portfolio/"
    }
    expiration {
      expired_object_delete_marker = true
    }
  }
  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {
      prefix = ""
    }
    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
  lifecycle {
    prevent_destroy = true
  }
}
