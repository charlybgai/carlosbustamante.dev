# CloudFront function to rewrite requests to index.html
resource "aws_cloudfront_function" "rewrite_index" {
  name    = "carlosbustamante-rewrite-index-html"
  runtime = "cloudfront-js-1.0"
  comment = "Appends index.html to directory requests for SPA/Static sites"
  publish = true
  code    = <<EOF
function handler(event) {
    var request = event.request;
    var uri = request.uri;
    
    if (uri.endsWith('/')) {
        request.uri += 'index.html';
    } 
    else if (!uri.includes('.')) {
        request.uri += '/index.html';
    }

    return request;
}
EOF
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# Origin Access Control for S3 content buckets
resource "aws_cloudfront_origin_access_control" "content" {
  for_each                          = local.content_sites
  name                              = "${each.value}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "carlosbustamante-security-headers"
  comment = "Security headers for carlosbustamante.dev"

  security_headers_config {
    content_type_options {
      override = true
    }

    frame_options {
      frame_option = "DENY"
      override     = true
    }

    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }

    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
  }

  custom_headers_config {
    items {
      header   = "Content-Security-Policy-Report-Only"
      value    = local.content_security_policy
      override = true
    }

    items {
      header   = "Permissions-Policy"
      value    = "camera=(), geolocation=(), microphone=()"
      override = true
    }
  }
}

# CloudFront distribution for content site
resource "aws_cloudfront_distribution" "content" {
  for_each            = local.content_sites
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [each.value]

  origin {
    domain_name              = aws_s3_bucket.content[each.key].bucket_regional_domain_name
    origin_id                = "S3-${each.value}"
    origin_access_control_id = aws_cloudfront_origin_access_control.content[each.key].id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${each.value}"

    # AWS managed "CachingOptimized": no query strings or cookies in the cache key (same as the
    # old legacy settings), Gzip and Brotli enabled, default TTL 1 day. deploy.sh invalidates
    # /* on every deploy, so the longer TTL doesn't serve stale files.
    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_index.arn
    }
  }

  # A missing object in the private bucket comes back from S3 as 403 (CloudFront has no
  # s3:ListBucket), so both codes are answered with the bilingual 404 page and a real 404.
  dynamic "custom_error_response" {
    for_each = [403, 404]
    content {
      error_code            = custom_error_response.value
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 60
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }
}

# CloudFront distribution for www redirect
resource "aws_cloudfront_distribution" "www" {
  enabled         = true
  is_ipv6_enabled = true
  aliases         = ["www.${var.root_domain}"]

  origin {
    domain_name = aws_s3_bucket_website_configuration.www.website_endpoint
    origin_id   = "S3-www-redirect"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-www-redirect"

    # Forward the query string so the S3 redirect keeps it (e.g. UTM tags on www links)
    forwarded_values {
      query_string = true
      cookies { forward = "none" }
    }

    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  viewer_certificate {
    acm_certificate_arn      = coalesce(var.www_certificate_arn, var.certificate_arn)
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }
}
