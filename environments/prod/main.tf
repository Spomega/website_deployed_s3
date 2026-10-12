module "website" {
  source = "../../modules/static_website"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  common_tags  = var.common_tags
}
