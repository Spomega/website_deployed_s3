output "state_bucket_name" {
  description = "Name of the S3 bucket used by environment Terraform backends."
  value       = aws_s3_bucket.terraform_state.bucket
}

output "state_bucket_region" {
  description = "AWS Region of the Terraform state bucket."
  value       = var.aws_region
}

output "github_actions_role_arn" {
  description = "Set this value as AWS_ROLE_TO_ASSUME in each GitHub Environment."
  value       = aws_iam_role.github_actions_deploy.arn
}

output "github_repository" {
  description = "GitHub repository trusted to use the deployment role."
  value       = var.github_repository
}
