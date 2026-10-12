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

variable "common_tags" {
  description = "Tags applied to supported bootstrap resources."
  type        = map(string)
  default = {
    ManagedBy = "Terraform"
    Project   = "kojo-profile"
    Purpose   = "terraform-state"
  }
}
