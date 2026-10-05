# Alerts for the contact form and the site itself. Every alarm emails the alert address through SNS.
# After the first apply, AWS sends a confirmation email: click the link or no alerts arrive.

resource "aws_sns_topic" "contact_alerts" {
  name = "contact-form-alerts"
}

resource "aws_sns_topic_subscription" "contact_alerts_email" {
  topic_arn = aws_sns_topic.contact_alerts.arn
  protocol  = "email"
  endpoint  = coalesce(var.alert_email, var.contact_recipient_email)
}

# Any 5XX returned by the API: the Lambda answers 503 when reCAPTCHA or SES fail and 500 on
# an unexpected error, and API Gateway answers 502/504 when the Lambda crashes or times out.
# Real traffic is a handful of messages a month, so a single error is worth an email.
resource "aws_cloudwatch_metric_alarm" "contact_api_5xx" {
  alarm_name        = "contact-api-5xx"
  alarm_description = "The contact form API returned a 5XX. Check the /aws/lambda/SendEmailFunction logs for UPSTREAM_ERROR or UNHANDLED_ERROR."
  namespace         = "AWS/ApiGateway"
  metric_name       = "5XXError"
  dimensions = {
    ApiName = aws_api_gateway_rest_api.send_email.name
    Stage   = aws_api_gateway_stage.prod.stage_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.contact_alerts.arn]
  ok_actions          = [aws_sns_topic.contact_alerts.arn]
}

# Lambda invocation errors (crashes outside the handler, timeouts, out of memory). Handled
# errors return a 5XX and are caught by the alarm above.
resource "aws_cloudwatch_metric_alarm" "contact_lambda_errors" {
  alarm_name        = "contact-lambda-errors"
  alarm_description = "SendEmailFunction failed to run (crash, timeout or out of memory). Check its CloudWatch logs."
  namespace         = "AWS/Lambda"
  metric_name       = "Errors"
  dimensions = {
    FunctionName = aws_lambda_function.send_email.function_name
  }
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.contact_alerts.arn]
  ok_actions          = [aws_sns_topic.contact_alerts.arn]
}

# Is the site up? Route 53 requests the home page over HTTPS from several regions every 30
# seconds; three failures in a row mark it unhealthy. Route 53 publishes health check metrics
# only in us-east-1, which is where this alarm lives.
resource "aws_route53_health_check" "site" {
  fqdn              = var.root_domain
  type              = "HTTPS"
  port              = 443
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3
  enable_sni        = true

  tags = {
    Name = "${var.root_domain}-home"
  }
}

resource "aws_cloudwatch_metric_alarm" "site_down" {
  alarm_name        = "portfolio-site-down"
  alarm_description = "https://${var.root_domain}/ failed Route 53 health checks for 2 minutes. Check CloudFront, the S3 origin and the last deploy."
  namespace         = "AWS/Route53"
  metric_name       = "HealthCheckStatus"
  dimensions = {
    HealthCheckId = aws_route53_health_check.site.id
  }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "missing"
  alarm_actions       = [aws_sns_topic.contact_alerts.arn]
  ok_actions          = [aws_sns_topic.contact_alerts.arn]
}
