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

resource "aws_iam_role_policy_attachment" "ses_full_access" {
  role       = aws_iam_role.send_email.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
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
      ALLOWED_ORIGIN     = "https://${var.root_domain}"
      CONTACT_SENDER     = var.contact_sender_email
      CONTACT_RECIPIENT  = var.contact_recipient_email
      GCP_API_KEY        = google_apikeys_key.recaptcha_assessment.key_string
      GCP_PROJECT_ID     = var.gcp_project_id
      RECAPTCHA_SITE_KEY = google_recaptcha_enterprise_key.portfolio_contact_form.name
    }
  }
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
    "method.response.header.Access-Control-Allow-Origin"  = "'https://carlosbustamante.dev'"
  }

  depends_on = [
    aws_api_gateway_integration.sendemail_options
  ]
}

resource "aws_api_gateway_deployment" "send_email" {
  rest_api_id = aws_api_gateway_rest_api.send_email.id
  description = "Fix both root and sendemail OPTIONS CORS"

  depends_on = [
    aws_api_gateway_integration.sendemail_post,
    aws_api_gateway_integration_response.sendemail_options
  ]
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.send_email.id
  deployment_id = aws_api_gateway_deployment.send_email.id
  stage_name    = "prod"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.send_email.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.send_email.execution_arn}/*/*"
}
