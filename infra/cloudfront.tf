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

# Origin Access Control for S3 content buckets
resource "aws_cloudfront_origin_access_control" "content" {
  for_each                          = local.content_sites
  name                              = "${each.value}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
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

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.rewrite_index.arn
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

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }

    viewer_protocol_policy = "redirect-to-https"
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
