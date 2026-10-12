variable "aws_region" {
  description = "AWS Region for the production website origin."
  type        = string
  default     = "eu-central-1"
}

variable "aws_profile" {
  description = "AWS CLI profile Terraform uses for production."
  type        = string
  default     = "spomega"
}

variable "project_name" {
  description = "DNS-compliant project name shared by environments."
  type        = string
  default     = "kojo-profile"
}

variable "environment" {
  description = "Environment identifier passed to the shared module."
  type        = string
  default     = "prod"
}

variable "common_tags" {
  description = "Additional tags applied to supported resources."
  type        = map(string)
  default = {
    Owner = "Kojo Mensah"
  }
}
