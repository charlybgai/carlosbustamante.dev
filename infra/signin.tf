# ConsoleLogin is emitted in the sign-in endpoint's region. Forward matching events
# from every currently enabled region to us-east-1 and the existing confirmed SNS topic.
locals {
  signin_rule_name = "portfolio-break-glass-sign-in"
  # Keep trust stable when only the rule's event pattern changes.
  signin_rule_arn = "arn:${data.aws_partition.current.partition}:events:us-east-1:${data.aws_caller_identity.current.account_id}:rule/${local.signin_rule_name}"
  signin_pattern = jsonencode({
    source        = ["aws.signin"]
    "detail-type" = ["AWS Console Sign In via CloudTrail"]
    account       = [data.aws_caller_identity.current.account_id]
    detail = {
      eventSource = ["signin.amazonaws.com"]
      eventName   = ["ConsoleLogin"]
      "$or" = [
        { userIdentity = { type = ["Root"] } },
        { userIdentity = { type = ["IAMUser"], userName = ["Charly"] } },
      ]
    }
  })
  signin_forward_regions = [
    "ap-northeast-1", "ap-northeast-2", "ap-northeast-3", "ap-south-1",
    "ap-southeast-1", "ap-southeast-2", "ca-central-1", "eu-central-1",
    "eu-north-1", "eu-west-1", "eu-west-2", "eu-west-3", "sa-east-1",
    "us-east-2", "us-west-1", "us-west-2",
  ]
  signin_forward_rule_arns = [for region in local.signin_forward_regions :
    "arn:${data.aws_partition.current.partition}:events:${region}:${data.aws_caller_identity.current.account_id}:rule/${local.signin_rule_name}"
  ]
  signin_destination_bus_arn = "arn:${data.aws_partition.current.partition}:events:us-east-1:${data.aws_caller_identity.current.account_id}:event-bus/default"
}

resource "aws_cloudwatch_event_rule" "signin" {
  name          = local.signin_rule_name
  description   = "Notify on recognized root or Charly console sign-in attempts, including regional sign-ins."
  event_pattern = local.signin_pattern
  depends_on    = [aws_cloudtrail.management]
}

# An execution role limits SNS publishing to this rule and this one topic. It avoids
# a broad events.amazonaws.com grant on the topic and preserves its alarm permissions.
data "aws_iam_policy_document" "signin_notify_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [local.signin_rule_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "signin_notify" {
  name               = "portfolio-signin-notify"
  assume_role_policy = data.aws_iam_policy_document.signin_notify_trust.json
}

resource "aws_iam_role_policy" "signin_notify" {
  name = "publish-signin-alert"
  role = aws_iam_role.signin_notify.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "sns:Publish"
      Resource = aws_sns_topic.contact_alerts.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "signin" {
  rule       = aws_cloudwatch_event_rule.signin.name
  target_id  = "email-signin-alert"
  arn        = aws_sns_topic.contact_alerts.arn
  role_arn   = aws_iam_role.signin_notify.arn
  depends_on = [aws_iam_role_policy.signin_notify]
}

data "aws_iam_policy_document" "signin_forward_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = local.signin_forward_rule_arns
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_iam_role" "signin_forward" {
  name               = "portfolio-signin-forward"
  assume_role_policy = data.aws_iam_policy_document.signin_forward_trust.json
}

resource "aws_iam_role_policy" "signin_forward" {
  name = "forward-signin-alert"
  role = aws_iam_role.signin_forward.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "events:PutEvents"
      Resource = local.signin_destination_bus_arn
    }]
  })
}
