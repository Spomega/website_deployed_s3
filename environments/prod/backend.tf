terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Supply the bucket at initialization:
  # terraform init -backend-config="bucket=YOUR_STATE_BUCKET_NAME"
  backend "s3" {
    key          = "website/prod/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}
