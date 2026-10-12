output "cloudfront_url" {
  description = "HTTPS URL for Kojo's production website."
  value       = module.website.cloudfront_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID for the production website."
  value       = module.website.cloudfront_distribution_id
}

output "website_bucket_name" {
  description = "Private S3 bucket name for the production origin."
  value       = module.website.website_bucket_name
}

output "s3_website_endpoint" {
  description = "Private S3 website endpoint; it should return AccessDenied."
  value       = module.website.s3_website_endpoint
}

output "direct_s3_index_url" {
  description = "Private direct object URL; it should return AccessDenied."
  value       = module.website.direct_s3_index_url
}
