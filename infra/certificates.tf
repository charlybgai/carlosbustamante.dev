# Watch the exact ARNs used by CloudFront; do not create or adopt certificates here.
locals {
  monitored_certificates = {
    apex = var.certificate_arn
    www  = coalesce(var.www_certificate_arn, var.certificate_arn)
  }
}

# ACM emits DaysToExpiry twice daily, not every minute. A daily Minimum retains
# the last available expiry value. Missing data keeps the previous alarm state,
# including ALARM after ACM stops publishing for an expired certificate.
# https://docs.aws.amazon.com/acm/latest/userguide/cloudwatch-metrics.html
resource "aws_cloudwatch_metric_alarm" "certificate_expiry" {
  for_each = local.monitored_certificates

  alarm_name          = "portfolio-certificate-${each.key}-expiry"
  alarm_description   = "The ${each.key} CloudFront certificate expires in fewer than 30 days. Check ACM managed renewal and its DNS validation record in us-east-1."
  namespace           = "AWS/CertificateManager"
  metric_name         = "DaysToExpiry"
  dimensions          = { CertificateArn = each.value }
  statistic           = "Minimum"
  period              = 86400
  evaluation_periods  = 1
  threshold           = 30
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "ignore"
  alarm_actions       = [aws_sns_topic.contact_alerts.arn]
  ok_actions          = [aws_sns_topic.contact_alerts.arn]
}
