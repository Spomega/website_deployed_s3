variable "aws_region" {
  description = "AWS Region that contains the remote Terraform state bucket."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile Terraform uses for the bootstrap resources."
  type        = string
  default     = "spomega"
}

variable "state_bucket_name" {
  description = "Globally unique, DNS-compliant name for the remote Terraform state bucket."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the deployment role, in OWNER/REPOSITORY format."
  type        = string
  default     = "Spomega/website_deployed_s3"

  validation {
    condition     = can(regex("^[^/]+/[^/]+$", var.github_repository))
    error_message = "github_repository must use the OWNER/REPOSITORY format."
  }
}

variable "github_environments" {
  description = "GitHub Environments allowed to assume the deployment role."
  type        = set(string)
  default     = ["dev", "staging", "prod"]

  validation {
    condition     = alltrue([for environment in var.github_environments : contains(["dev", "staging", "prod"], environment)])
    error_message = "github_environments can contain only dev, staging, and prod."
  }
}

variable "github_actions_role_name" {
  description = "Name of the IAM role GitHub Actions assumes for Terraform deployments."
  type        = string
  default     = "github-actions-website-deploy"
}

variable "website_project_name" {
  description = "Project name used to scope website bucket permissions."
  type        = string
  default     = "kojo-profile"
}

variable "common_tags" {
  description = "Tags applied to supported bootstrap resources."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "kojo-profile"
    Purpose   = "terraform-state"
  }
}
