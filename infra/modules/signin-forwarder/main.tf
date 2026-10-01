terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

variable "rule_name" {
  type = string
}

variable "event_pattern" {
  type = string
}

variable "destination_bus_arn" {
  type = string
}

variable "forward_role_arn" {
  type = string
}

resource "aws_cloudwatch_event_rule" "signin" {
  name          = var.rule_name
  description   = "Forward root and Charly console sign-in attempts to the account alert region."
  event_pattern = var.event_pattern
}

resource "aws_cloudwatch_event_target" "signin" {
  rule      = aws_cloudwatch_event_rule.signin.name
  target_id = "forward-signin-alert"
  arn       = var.destination_bus_arn
  role_arn  = var.forward_role_arn
}
