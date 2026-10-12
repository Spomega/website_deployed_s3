provider "aws" {
  region = var.aws_region
  # Local development uses the configured profile; CI supplies OIDC credentials.
  profile = var.aws_profile != "" ? var.aws_profile : null
}
