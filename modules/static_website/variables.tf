variable "project_name" {
  description = "DNS-compliant project name used to name website resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be lowercase, DNS-compliant, and 3 to 32 characters long."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be dev, staging, or prod."
  }
}

variable "aws_region" {
  description = "AWS Region where the S3 website bucket is created."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to supported website resources."
  type        = map(string)
  default     = {}
}
