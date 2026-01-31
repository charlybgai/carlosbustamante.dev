data "aws_route53_zone" "main" {
  name = var.root_domain
}

# DNS records for content sites
resource "aws_route53_record" "content" {
  for_each = local.content_sites
  zone_id  = data.aws_route53_zone.main.zone_id
  name     = each.value
  type     = "A"

  alias {
    name                   = aws_cloudfront_distribution.content[each.key].domain_name
    zone_id                = aws_cloudfront_distribution.content[each.key].hosted_zone_id
    evaluate_target_health = false
  }
}

# DNS record for www redirect
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.root_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www.domain_name
    zone_id                = aws_cloudfront_distribution.www.hosted_zone_id
    evaluate_target_health = false
  }
}
