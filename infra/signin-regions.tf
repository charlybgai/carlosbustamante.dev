# Static aliases are required by Terraform 1.15 / AWS provider 5.x.
# These cover all enabled regions checked during B3. When enabling another AWS
# region, add its provider/module here and its ARN to signin_forward_regions.

provider "aws" {
  alias  = "ap_northeast_1"
  region = "ap-northeast-1"
}

module "signin_ap_northeast_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ap_northeast_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "ap_northeast_2"
  region = "ap-northeast-2"
}

module "signin_ap_northeast_2" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ap_northeast_2 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "ap_northeast_3"
  region = "ap-northeast-3"
}

module "signin_ap_northeast_3" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ap_northeast_3 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "ap_south_1"
  region = "ap-south-1"
}

module "signin_ap_south_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ap_south_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "ap_southeast_1"
  region = "ap-southeast-1"
}

module "signin_ap_southeast_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ap_southeast_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "ap_southeast_2"
  region = "ap-southeast-2"
}

module "signin_ap_southeast_2" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ap_southeast_2 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "ca_central_1"
  region = "ca-central-1"
}

module "signin_ca_central_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.ca_central_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "eu_central_1"
  region = "eu-central-1"
}

module "signin_eu_central_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.eu_central_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "eu_north_1"
  region = "eu-north-1"
}

module "signin_eu_north_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.eu_north_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "eu_west_1"
  region = "eu-west-1"
}

module "signin_eu_west_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.eu_west_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "eu_west_2"
  region = "eu-west-2"
}

module "signin_eu_west_2" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.eu_west_2 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "eu_west_3"
  region = "eu-west-3"
}

module "signin_eu_west_3" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.eu_west_3 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "sa_east_1"
  region = "sa-east-1"
}

module "signin_sa_east_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.sa_east_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "us_east_2"
  region = "us-east-2"
}

module "signin_us_east_2" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.us_east_2 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "us_west_1"
  region = "us-west-1"
}

module "signin_us_west_1" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.us_west_1 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}

provider "aws" {
  alias  = "us_west_2"
  region = "us-west-2"
}

module "signin_us_west_2" {
  source    = "./modules/signin-forwarder"
  providers = { aws = aws.us_west_2 }

  rule_name           = local.signin_rule_name
  event_pattern       = local.signin_pattern
  destination_bus_arn = local.signin_destination_bus_arn
  forward_role_arn    = aws_iam_role.signin_forward.arn

  depends_on = [aws_cloudtrail.management, aws_iam_role_policy.signin_forward]
}
