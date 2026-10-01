data "archive_file" "send_email" {
  type        = "zip"
  source_file = "${path.module}/../functions/send_email/lambda_function.py"
  output_path = "${path.module}/../functions/send_email/lambda_function.zip"
}

resource "aws_iam_role" "send_email" {
  name = "SendEmailFunctionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.send_email.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_caller_identity" "current" {}

locals {
  # The only origin the contact API answers (Lambda headers, OPTIONS and gateway responses)
  allowed_origin = "https://${var.root_domain}"

  # SES checks SendEmail against the verified identity of the sender. In the SES sandbox the
  # recipient must be a verified identity as well, so both addresses' domains are allowed.
  ses_identity_arns = distinct([
    for address in [var.contact_sender_email, var.contact_recipient_email] :
    "arn:aws:ses:us-east-1:${data.aws_caller_identity.current.account_id}:identity/${split("@", address)[1]}"
  ])
}

# Least privilege: the function can only send from the contact sender, to the contact recipient.
resource "aws_iam_role_policy" "send_email_ses" {
  name = "SendContactEmail"
  role = aws_iam_role.send_email.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SendContactFormEmail"
        Effect   = "Allow"
        Action   = "ses:SendEmail"
        Resource = local.ses_identity_arns
        Condition = {
          StringEquals = {
            "ses:FromAddress" = var.contact_sender_email
          }
          "ForAllValues:StringEquals" = {
            "ses:Recipients" = [var.contact_recipient_email]
          }
        }
      }
    ]
  })
}

resource "aws_lambda_function" "send_email" {
  function_name    = "SendEmailFunction"
  role             = aws_iam_role.send_email.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.send_email.output_path
  source_code_hash = data.archive_file.send_email.output_base64sha256
  memory_size      = 128
  timeout          = 10

  environment {
    variables = {
      ALLOWED_ORIGIN     = local.allowed_origin
      CONTACT_SENDER     = var.contact_sender_email
      CONTACT_RECIPIENT  = var.contact_recipient_email
      GCP_API_KEY        = google_apikeys_key.recaptcha_assessment.key_string
      GCP_PROJECT_ID     = var.gcp_project_id
      RECAPTCHA_SITE_KEY = google_recaptcha_enterprise_key.portfolio_contact_form.name
    }
  }
}

# Adopted from the log group Lambda created on first run (imported on 2026-09-29).
resource "aws_cloudwatch_log_group" "send_email" {
  name              = "/aws/lambda/${aws_lambda_function.send_email.function_name}"
  retention_in_days = 90
}

resource "aws_api_gateway_rest_api" "send_email" {
  name        = "SendEmailAPI"
  description = "Send email from carlosbustamante.dev"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "sendemail" {
  rest_api_id = aws_api_gateway_rest_api.send_email.id
  parent_id   = aws_api_gateway_rest_api.send_email.root_resource_id
  path_part   = "sendemail"
}

resource "aws_api_gateway_method" "sendemail_post" {
  rest_api_id   = aws_api_gateway_rest_api.send_email.id
  resource_id   = aws_api_gateway_resource.sendemail.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "sendemail_post" {
  rest_api_id             = aws_api_gateway_rest_api.send_email.id
  resource_id             = aws_api_gateway_resource.sendemail.id
  http_method             = aws_api_gateway_method.sendemail_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.send_email.invoke_arn
}

resource "aws_api_gateway_method" "sendemail_options" {
  rest_api_id   = aws_api_gateway_rest_api.send_email.id
  resource_id   = aws_api_gateway_resource.sendemail.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "sendemail_options" {
  rest_api_id = aws_api_gateway_rest_api.send_email.id
  resource_id = aws_api_gateway_resource.sendemail.id
  http_method = aws_api_gateway_method.sendemail_options.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "sendemail_options" {
  rest_api_id          = aws_api_gateway_rest_api.send_email.id
  resource_id          = aws_api_gateway_resource.sendemail.id
  http_method          = aws_api_gateway_method.sendemail_options.http_method
  type                 = "MOCK"
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_integration_response" "sendemail_options" {
  rest_api_id = aws_api_gateway_rest_api.send_email.id
  resource_id = aws_api_gateway_resource.sendemail.id
  http_method = aws_api_gateway_method.sendemail_options.http_method
  status_code = aws_api_gateway_method_response.sendemail_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type'"
    "method.response.header.Access-Control-Allow-Methods" = "'OPTIONS,POST'"
    "method.response.header.Access-Control-Allow-Origin"  = "'${local.allowed_origin}'"
  }

  depends_on = [
    aws_api_gateway_integration.sendemail_options
  ]
}

# Errors that API Gateway produces itself (throttling = 429, Lambda crash or timeout = 502/504,
# unknown path = 403) don't come from the Lambda, so they had no CORS header and the browser
# couldn't read them. Customizing the two defaults covers every 4XX/5XX type that isn't
# customized on its own, THROTTLED included.
resource "aws_api_gateway_gateway_response" "cors" {
  for_each      = toset(["DEFAULT_4XX", "DEFAULT_5XX"])
  rest_api_id   = aws_api_gateway_rest_api.send_email.id
  response_type = each.key

  response_parameters = {
    "gatewayresponse.header.Access-Control-Allow-Origin" = "'${local.allowed_origin}'"
  }
}

# A deployment is a snapshot of the API. `triggers` hashes every resource that defines the API,
# so any change to them creates a new deployment and the prod stage picks it up.
# create_before_destroy lets the stage move to the new deployment before the old one is deleted.
resource "aws_api_gateway_deployment" "send_email" {
  rest_api_id = aws_api_gateway_rest_api.send_email.id
  description = "Managed by Terraform"

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.sendemail,
      aws_api_gateway_method.sendemail_post,
      aws_api_gateway_integration.sendemail_post,
      aws_api_gateway_method.sendemail_options,
      aws_api_gateway_method_response.sendemail_options,
      aws_api_gateway_integration.sendemail_options,
      aws_api_gateway_integration_response.sendemail_options,
      aws_api_gateway_gateway_response.cors,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.send_email.id
  deployment_id = aws_api_gateway_deployment.send_email.id
  stage_name    = "prod"
}

# Throttle every method on the stage (the account default is 10,000 requests/s). Each form
# submission is two requests (the CORS preflight and the POST), and SES in this account sends
# at most 1 email/s, so this is plenty for real visitors and caps abuse of Lambda/reCAPTCHA.
resource "aws_api_gateway_method_settings" "prod" {
  rest_api_id = aws_api_gateway_rest_api.send_email.id
  stage_name  = aws_api_gateway_stage.prod.stage_name
  method_path = "*/*"

  settings {
    throttling_rate_limit  = 2
    throttling_burst_limit = 5
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_email.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.send_email.execution_arn}/*/*"
}
