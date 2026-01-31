output "content_bucket_names" {
  description = "Names of content S3 buckets"
  value       = { for k, v in aws_s3_bucket.content : k => v.bucket }
}

output "www_bucket_name" {
  description = "Name of WWW redirect S3 bucket"
  value       = aws_s3_bucket.www.bucket
}

output "cloudfront_distribution_ids" {
  description = "IDs of content CloudFront distributions"
  value       = { for k, v in aws_cloudfront_distribution.content : k => v.id }
}

output "www_cloudfront_distribution_id" {
  description = "ID of WWW redirect CloudFront distribution"
  value       = aws_cloudfront_distribution.www.id
}

output "cloudfront_domain_names" {
  description = "Domain names of CloudFront distributions"
  value       = { for k, v in aws_cloudfront_distribution.content : k => v.domain_name }
}
