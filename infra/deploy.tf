# Deploys from GitHub Actions: the CI workflow assumes this role through GitHub's OIDC provider
# (no stored AWS keys) and runs deploy.sh after every check on main passes. The role can do only
# what deploy.sh needs: sync the root bucket and invalidate its CloudFront distribution.
#
# One OIDC provider per URL is allowed per account. If the account already has GitHub's, import
# it before applying: terraform import aws_iam_openid_connect_provider.github <provider ARN>
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

locals {
  # Jobs that use a GitHub environment get an environment-based subject, so only the deploy job
  # (environment "production", limited to main in the repo settings) can assume the role.
  github_deploy_subject = "repo:${var.github_repository}:environment:production"
}

resource "aws_iam_role" "github_deploy" {
  name                 = "portfolio-github-deploy"
  description          = "Assumed by the GitHub Actions deploy job of ${var.github_repository}"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "GitHubActionsProductionEnvironment"
        Effect    = "Allow"
        Action    = "sts:AssumeRoleWithWebIdentity"
        Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.github_deploy_subject
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "github_deploy" {
  name = "DeploySite"
  role = aws_iam_role.github_deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListSiteBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.content["root"].arn
      },
      {
        Sid      = "SyncSiteObjects"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.content["root"].arn}/*"
      },
      {
        Sid      = "InvalidateSiteCache"
        Effect   = "Allow"
        Action   = ["cloudfront:CreateInvalidation", "cloudfront:GetInvalidation"]
        Resource = aws_cloudfront_distribution.content["root"].arn
      }
    ]
  })
}
