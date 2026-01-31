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

resource "aws_s3_bucket_public_access_block" "www" {
  bucket = aws_s3_bucket.www.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "www" {
  bucket = aws_s3_bucket.www.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowPublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.www.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.www]
}
