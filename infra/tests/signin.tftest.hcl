# External event contract from the CloudTrail integration reference:
# https://docs.aws.amazon.com/awscloudtrail/latest/userguide/cloudtrail-aws-service-specific-topics.html
# The spelling in the general EventBridge overview differs; use the integration's event type.
# Mock providers keep these regression checks offline, including all regional aliases.
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }
  # Supply syntactically valid stand-ins for policy-document data sources. This
  # test checks event matching; actual IAM policy scope is verified separately.
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({ Version = "2012-10-17", Statement = [] })
    }
  }
}

mock_provider "aws" {
  alias = "ap_northeast_1"
}

mock_provider "aws" {
  alias = "ap_northeast_2"
}

mock_provider "aws" {
  alias = "ap_northeast_3"
}

mock_provider "aws" {
  alias = "ap_south_1"
}

mock_provider "aws" {
  alias = "ap_southeast_1"
}

mock_provider "aws" {
  alias = "ap_southeast_2"
}

mock_provider "aws" {
  alias = "ca_central_1"
}

mock_provider "aws" {
  alias = "eu_central_1"
}

mock_provider "aws" {
  alias = "eu_north_1"
}

mock_provider "aws" {
  alias = "eu_west_1"
}

mock_provider "aws" {
  alias = "eu_west_2"
}

mock_provider "aws" {
  alias = "eu_west_3"
}

mock_provider "aws" {
  alias = "sa_east_1"
}

mock_provider "aws" {
  alias = "us_east_2"
}

mock_provider "aws" {
  alias = "us_west_1"
}

mock_provider "aws" {
  alias = "us_west_2"
}

mock_provider "google" {}
mock_provider "google-beta" {}
mock_provider "archive" {}

variables {
  gcp_project_id      = "offline-ci-project"
  root_domain         = "example.com"
  certificate_arn     = "arn:aws:acm:us-east-1:123456789012:certificate/00000000-0000-0000-0000-000000000000"
  www_certificate_arn = null
}

run "cloudtrail_console_sign_in_contract" {
  command = plan

  assert {
    condition     = contains(jsondecode(local.signin_pattern)["detail-type"], "AWS Console Sign In via CloudTrail")
    error_message = "ConsoleLogin notifications must match AWS's 'AWS Console Sign In via CloudTrail' event type (with spaces in Sign In)."
  }
}

run "certificate_alerts_watch_cloudfront_certificates" {
  command = plan
  variables {
    www_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/11111111-1111-1111-1111-111111111111"
  }

  assert {
    condition = (
      aws_cloudwatch_metric_alarm.certificate_expiry["apex"].dimensions.CertificateArn == var.certificate_arn &&
      aws_cloudwatch_metric_alarm.certificate_expiry["www"].dimensions.CertificateArn == var.www_certificate_arn
    )
    error_message = "Expiry alerts must watch the exact certificates used by the two CloudFront distributions."
  }

  assert {
    condition = alltrue([
      for alarm in aws_cloudwatch_metric_alarm.certificate_expiry :
      alarm.namespace == "AWS/CertificateManager" && alarm.metric_name == "DaysToExpiry" &&
      alarm.period >= 43200 && alarm.period <= 86400 && alarm.evaluation_periods == 1 &&
      alarm.statistic == "Minimum" && alarm.treat_missing_data == "ignore" &&
      alarm.threshold == 30 && alarm.comparison_operator == "LessThanThreshold"
    ])
    error_message = "ACM reports twice daily: retain expiry warnings across missing data and evaluate fewer than 30 days within one day."
  }
}

run "certificate_alert_www_fallback" {
  command = plan
  variables {
    www_certificate_arn = null
  }

  assert {
    condition     = aws_cloudwatch_metric_alarm.certificate_expiry["www"].dimensions.CertificateArn == var.certificate_arn
    error_message = "When no separate www certificate is configured, watch the apex certificate just as CloudFront does."
  }
}
