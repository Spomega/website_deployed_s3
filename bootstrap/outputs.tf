output "state_bucket_name" {
  description = "Name of the S3 bucket used by environment Terraform backends."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_region" {
  description = "AWS Region of the Terraform state bucket."
  value       = var.aws_region
}
