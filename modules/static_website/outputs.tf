output "cloudfront_url" {
  description = "HTTPS URL for the website using CloudFront's default domain."
  value       = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for cache invalidations and operational checks."
  value       = aws_cloudfront_distribution.website.id
}

output "cloudfront_domain_name" {
  description = "CloudFront-assigned domain name."
  value       = aws_cloudfront_distribution.website.domain_name
}

output "website_bucket_name" {
  description = "Name of the private S3 website origin bucket."
  value       = aws_s3_bucket.website.bucket
}

output "website_bucket_regional_domain_name" {
  description = "Private S3 REST origin used by CloudFront."
  value       = aws_s3_bucket.website.bucket_regional_domain_name
}

output "s3_website_endpoint" {
  description = "S3 website endpoint, expected to return AccessDenied because the bucket is private."
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
}

output "direct_s3_index_url" {
  description = "Direct S3 object URL, expected to return AccessDenied because CloudFront is the only allowed reader."
  value       = "https://${aws_s3_bucket.website.bucket_regional_domain_name}/index.html"
}
