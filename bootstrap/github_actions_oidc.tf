data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  website_bucket_arns = [
    for environment in var.github_environments :
    "arn:${data.aws_partition.current.partition}:s3:::${var.website_project_name}-${environment}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  ]

  website_object_arns = [
    for bucket_arn in local.website_bucket_arns :
    "${bucket_arn}/*"
  ]
}

# This provider is account-wide and already exists in this account. Importing it
# lets Terraform reference it while preventing an accidental removal.
resource "aws_iam_openid_connect_provider" "github_actions" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ab9d0263244dd0326eb67015705a667e79cfe998"]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [tags, thumbprint_list]
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    sid     = "AllowGitHubActionsRepositoryEnvironments"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        for environment in var.github_environments :
        "repo:${var.github_repository}:environment:${environment}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_deploy" {
  name               = var.github_actions_role_name
  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  tags = merge(var.common_tags, {
    Name    = var.github_actions_role_name
    Purpose = "github-actions-terraform-deployment"
  })
}

data "aws_iam_policy_document" "github_actions_deploy" {
  statement {
    sid = "ManageTerraformStateBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:GetBucketVersioning",
      "s3:ListBucket",
      "s3:ListBucketVersions",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid = "ManageTerraformStateObjects"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]
  }

  # S3 requires a wildcard resource before a new, named bucket exists.
  statement {
    sid       = "CreateProjectWebsiteBuckets"
    actions   = ["s3:CreateBucket", "s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    sid = "ManageProjectWebsiteBuckets"
    actions = [
      "s3:DeleteBucket",
      "s3:DeleteBucketPolicy",
      "s3:DeleteBucketPublicAccessBlock",
      "s3:DeleteBucketWebsite",
      "s3:GetBucketEncryption",
      "s3:GetBucketOwnershipControls",
      "s3:GetBucketPolicy",
      "s3:GetBucketPublicAccessBlock",
      "s3:GetBucketTagging",
      "s3:GetBucketVersioning",
      "s3:GetBucketWebsite",
      "s3:PutBucketEncryption",
      "s3:PutBucketOwnershipControls",
      "s3:PutBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutBucketWebsite",
    ]
    resources = local.website_bucket_arns
  }

  statement {
    sid = "ManageProjectWebsiteObjects"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
    ]
    resources = local.website_object_arns
  }

  # CloudFront control-plane APIs do not support resource-level permissions.
  statement {
    sid = "ManageProjectCloudFrontResources"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:DeleteDistribution",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:GetCachePolicy",
      "cloudfront:GetDistribution",
      "cloudfront:GetDistributionConfig",
      "cloudfront:GetOriginAccessControl",
      "cloudfront:GetResponseHeadersPolicy",
      "cloudfront:ListDistributions",
      "cloudfront:ListOriginAccessControls",
      "cloudfront:ListTagsForResource",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:UpdateDistribution",
      "cloudfront:UpdateOriginAccessControl",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "github_actions_deploy" {
  name   = "${var.github_actions_role_name}-policy"
  role   = aws_iam_role.github_actions_deploy.id
  policy = data.aws_iam_policy_document.github_actions_deploy.json
}
