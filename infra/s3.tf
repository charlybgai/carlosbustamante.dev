locals {
  content_sites = merge(
    { "root" = var.root_domain },
    { for k, v in var.subdomains : k => "${v}.${var.root_domain}" }
  )
}

# Content bucket for root site
resource "aws_s3_bucket" "content" {
  for_each = local.content_sites
  bucket   = each.value
}

resource "aws_s3_bucket_public_access_block" "content" {
  for_each = local.content_sites
  bucket   = aws_s3_bucket.content[each.key].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "content" {
  for_each = local.content_sites
  bucket   = aws_s3_bucket.content[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFront"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.content[each.key].arn}/*"
      Condition = {
        StringEquals = {
          "AWS:SourceArn" = aws_cloudfront_distribution.content[each.key].arn
        }
      }
    }]
  })
}

# Versioning keeps the previous copy of every file deploy.sh overwrites or deletes, so a bad
# deploy can be rolled back from S3. Old copies expire after 30 days to keep storage negligible.
resource "aws_s3_bucket_versioning" "content" {
  for_each = local.content_sites
  bucket   = aws_s3_bucket.content[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "content" {
  for_each = local.content_sites
  bucket   = aws_s3_bucket.content[each.key].id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    # Delete markers left after their old versions expire
    expiration {
      expired_object_delete_marker = true
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 1
    }
  }

  depends_on = [aws_s3_bucket_versioning.content]
}

# WWW redirect bucket - redirects www.carlosbustamante.dev to carlosbustamante.dev
resource "aws_s3_bucket" "www" {
  bucket = "www.${var.root_domain}"
}

resource "aws_s3_bucket_website_configuration" "www" {
  bucket = aws_s3_bucket.www.id
  redirect_all_requests_to {
    host_name = var.root_domain
    protocol  = "https"
  }
}

# The bucket holds no objects: its website endpoint only answers every request with a 301 to
# the apex domain (redirect_all_requests_to), which works without public read access. So it
# stays fully private like the content bucket.
resource "aws_s3_bucket_public_access_block" "www" {
  bucket = aws_s3_bucket.www.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
