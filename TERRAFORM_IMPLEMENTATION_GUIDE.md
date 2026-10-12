# Secure S3, CloudFront, and Route 53 Website: Terraform Implementation Guide

## Scope

This guide translates the provided console exercise into Terraform. It intentionally **excludes PDF task 1** (account security, IAM identities, MFA, and budget), because those items are already complete.

The deployment will host a professional static profile website for **Kojo**:

- Private S3 bucket stores site files.
- CloudFront serves the site globally over HTTPS.
- CloudFront Origin Access Control (OAC) is the only identity allowed to read the bucket.
- A public Route 53 record is optional and is enabled only when a domain and ACM certificate are available.
- Terraform state is stored remotely in S3 and locked using `use_lockfile = true`.

## Important Design Decision

The PDF asks learners to enable S3 static website hosting, then later place CloudFront in front of a private bucket.

For the secure Terraform implementation:

- Configure `index.html` and `error.html` on the bucket to meet the learning objective.
- **Do not use the S3 website endpoint as the CloudFront origin.**
- Configure CloudFront with the bucket's regional S3 REST endpoint and OAC.

An S3 website endpoint is a custom origin and cannot use OAC. Using the REST endpoint keeps the bucket private and allows the CloudFront service principal to retrieve only the intended objects.

The S3 website endpoint and direct S3 object URL should return `AccessDenied`; only the CloudFront URL should display the site.

## Proposed Repository Layout

```text
website_deployed_s3/
├── Project_1_S3_CloudFront_Route53.pdf
├── TERRAFORM_IMPLEMENTATION_GUIDE.md
├── bootstrap/
│   ├── providers.tf
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/
│   └── static_website/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── versions.tf
│       └── site/
│           ├── index.html
│           ├── about.html
│           ├── error.html
│           ├── style.css
│           └── logo.svg
└── environments/
    ├── dev/
    │   ├── backend.tf
    │   ├── providers.tf
    │   ├── main.tf
    │   ├── variables.tf
    │   ├── terraform.tfvars.example
    │   └── outputs.tf
    ├── staging/
    │   └── ...same root-module files...
    └── prod/
        └── ...same root-module files...
```

`bootstrap/` must be applied first because Terraform cannot use a remote backend bucket until that bucket already exists.

Each environment is an independent Terraform root module with its own state key:

```text
website/dev/terraform.tfstate
website/staging/terraform.tfstate
website/prod/terraform.tfstate
```

Do not use Terraform workspaces for this exercise. Separate root modules make environment-specific configuration and review clearer for junior engineers.

## Step 0: Prerequisites

1. Confirm the existing AWS profile and target account:

   ```bash
   export AWS_PROFILE=spomega
   aws sts get-caller-identity
   ```

2. Install Terraform and use an AWS region for the S3 bucket, such as `eu-central-1`.
3. Pick globally unique bucket names. S3 bucket names must be lowercase, DNS-compliant, and contain no underscores.
4. For Route 53, own a domain and have access to its registrar. Otherwise, set `enable_custom_domain = false`.

## Step 1: Bootstrap the Remote Backend

Create a dedicated state bucket in `bootstrap/`; it is not the website-origin bucket.

Required backend-bucket controls:

- Globally unique name, for example `kojo-terraform-state-<account-id>`.
- S3 versioning enabled for recovery from accidental state changes.
- Server-side encryption enabled.
- Block all public access.
- TLS-only bucket policy.
- `prevent_destroy = true` lifecycle safeguard.

The bootstrap module should output the bucket name. Apply it using local state:

```bash
cd bootstrap
terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
```

Do not destroy this bucket when removing an environment. It retains the state needed to manage that environment.

## Step 2: Configure the S3 Remote Backend in Every Environment

Use an S3 backend in each environment's `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "REPLACE_WITH_BOOTSTRAP_BUCKET_NAME"
    key          = "website/dev/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}
```

Change only the `key` value in `staging` and `prod`.

`use_lockfile = true` makes Terraform create an S3 lock file while an operation is running. This prevents two operators from writing to the same state at the same time.

Do not put AWS credentials in `backend.tf`, source control, or `.tfvars` files. Terraform should use the configured AWS profile or short-lived IAM credentials.

Initialize each environment after bootstrap:

```bash
cd environments/dev
terraform init
terraform validate
```

If the backend configuration changes later, run:

```bash
terraform init -reconfigure
```

## Step 3: Define Provider and Environment Inputs

Each environment root sets the AWS provider and calls the shared module:

```hcl
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "website" {
  source = "../../modules/static_website"

  environment          = var.environment
  project_name         = var.project_name
  aws_region           = var.aws_region
  enable_custom_domain = var.enable_custom_domain
  domain_name          = var.domain_name
  hosted_zone_id       = var.hosted_zone_id
  acm_certificate_arn  = var.acm_certificate_arn
}
```

Example `environments/dev/terraform.tfvars`:

```hcl
aws_region           = "eu-central-1"
aws_profile          = "spomega"
environment          = "dev"
project_name         = "kojo-profile"
enable_custom_domain = false
```

Commit only `terraform.tfvars.example`. Keep actual `.tfvars` files out of version control if they ever contain private values.

## Step 4: Create the Private Website Bucket

The `static_website` module creates a website bucket with:

- `aws_s3_bucket`
- `aws_s3_bucket_public_access_block`
- `aws_s3_bucket_ownership_controls`
- `aws_s3_bucket_server_side_encryption_configuration`
- `aws_s3_bucket_versioning`
- `aws_s3_bucket_website_configuration`
- `aws_s3_object` resources for website files

Security requirements:

1. Set all four S3 Block Public Access options to `true`.
2. Use `BucketOwnerEnforced` object ownership, which disables ACLs.
3. Use default SSE-S3 encryption or a carefully scoped KMS key.
4. Never create a public-read bucket policy.
5. Enforce HTTPS to S3 using a `Deny` statement when `aws:SecureTransport` is `false`.

The website configuration should be:

```hcl
website {
  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
```

This configuration mirrors the PDF, but CloudFront will serve the files from the secure REST origin rather than from the S3 website endpoint.

## Step 5: Create Kojo's Professional Test Website

Store the five required files in `modules/static_website/site/` and upload them using `aws_s3_object`.

Required content:

| File | Purpose |
|---|---|
| `index.html` | Main profile / landing page |
| `about.html` | Professional biography and experience |
| `error.html` | Friendly not-found page |
| `style.css` | Shared responsive styling |
| `logo.svg` | Simple text or monogram logo |

Suggested profile content:

- **Name:** Kojo Mensah
- **Title:** Cloud and DevOps Engineer
- **Summary:** Builds secure, automated, and reliable cloud platforms.
- **Specialties:** Terraform, AWS, CI/CD, Linux, container platforms, monitoring.
- **Call to action:** “View my experience” linking to `about.html`.

Example main-page structure:

```html
<main>
  <p class="eyebrow">Cloud and DevOps Engineer</p>
  <h1>Kojo Mensah</h1>
  <p>I build secure, automated cloud platforms that help teams deliver reliably.</p>
  <a href="about.html">About Kojo</a>
</main>
```

Use `content_type` on every `aws_s3_object`, for example:

```hcl
content_type = "text/html"
```

Set the expected MIME types:

```text
index.html / about.html / error.html -> text/html
style.css                             -> text/css
logo.svg                              -> image/svg+xml
```

Do not mark these S3 objects public. CloudFront access is granted by the bucket policy in the next step.

## Step 6: Create CloudFront OAC and Distribution

Create `aws_cloudfront_origin_access_control` with:

```hcl
origin_access_control_origin_type = "s3"
signing_behavior                  = "always"
signing_protocol                  = "sigv4"
```

Create `aws_cloudfront_distribution` that:

- Uses the S3 bucket's `bucket_regional_domain_name` as the origin domain name.
- Associates the OAC with that origin.
- Sets `default_root_object = "index.html"`.
- Redirects HTTP viewers to HTTPS using `viewer_protocol_policy = "redirect-to-https"`.
- Uses the managed `CachingOptimized` cache policy.
- Uses the managed `SecurityHeadersPolicy` response headers policy.
- Sets `price_class = "PriceClass_100"` for a lower-cost learning environment.
- Enables the distribution.

Do not use `website_endpoint` as `domain_name` for the origin. It would turn the origin into a custom origin, preventing OAC from protecting it.

For the initial non-custom-domain deployment, use:

```hcl
viewer_certificate {
  cloudfront_default_certificate = true
}
```

CloudFront then provides a default `*.cloudfront.net` HTTPS URL.

## Step 7: Allow Only CloudFront to Read from S3

Create an `aws_s3_bucket_policy` that allows only the CloudFront service principal to read the website objects:

```json
{
  "Effect": "Allow",
  "Principal": {
    "Service": "cloudfront.amazonaws.com"
  },
  "Action": "s3:GetObject",
  "Resource": "arn:aws:s3:::BUCKET_NAME/*",
  "Condition": {
    "StringEquals": {
      "AWS:SourceArn": "arn:aws:cloudfront::ACCOUNT_ID:distribution/DISTRIBUTION_ID"
    }
  }
}
```

The `AWS:SourceArn` condition prevents another CloudFront distribution from using the policy. Terraform should construct the value from `aws_cloudfront_distribution.website.arn`; do not hardcode it.

Keep this CloudFront allow statement and the TLS-deny statement. Do not add any public-read allow statement.

## Step 8: Optional Route 53 Custom Domain

This is optional because it requires a registered domain.

1. Create or reference a public hosted zone:

   ```hcl
   data "aws_route53_zone" "website" {
     name         = var.domain_name
     private_zone = false
   }
   ```

2. Request an ACM public certificate in **`us-east-1`**. CloudFront only accepts ACM viewer certificates from that region.
3. Create DNS-validation records in Route 53 using `aws_route53_record`.
4. Wait for `aws_acm_certificate_validation`.
5. Add `aliases = [var.domain_name]` to CloudFront and use the validated ACM certificate ARN.
6. Create an alias `A` record pointing to the CloudFront distribution:

   ```hcl
   alias {
     name                   = aws_cloudfront_distribution.website.domain_name
     zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
     evaluate_target_health = false
   }
   ```

Also create an `AAAA` alias record if IPv6 is enabled.

After creating a hosted zone, update the domain registrar with the Route 53 name servers. DNS will not resolve until delegation is complete.

## Step 9: Outputs

The module should expose:

```hcl
output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.website.domain_name}"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.website.id
}

output "website_bucket_name" {
  value = aws_s3_bucket.website.bucket
}
```

When the custom-domain option is enabled, also output:

```hcl
output "custom_domain_url" {
  value = "https://${var.domain_name}"
}
```

## Step 10: Deploy Dev First

Deploy only development first:

```bash
cd environments/dev
terraform fmt -recursive
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output cloudfront_url
```

Repeat the same review process separately for staging and production.

Never run `terraform apply` from the repository root; always run it from one specific environment directory.

## Step 11: Verification Checklist

Run the following checks after CloudFront status is deployed:

```bash
terraform output -raw cloudfront_url
```

1. Open the CloudFront URL. It must load the Kojo profile over HTTPS.
2. Confirm the default CloudFront URL displays `index.html` without typing `/index.html`.
3. Confirm `https://<distribution-domain>/about.html` loads.
4. Attempt the direct S3 object URL. It must return `AccessDenied`.
5. Attempt the S3 website endpoint. It must return `AccessDenied`.
6. Test an invalid CloudFront route. Document the configured behavior for `error.html`.
7. Confirm S3 Block Public Access remains enabled.
8. Confirm no bucket policy uses `Principal: "*"`, except for a carefully scoped explicit TLS deny (which is not a public read grant).

CloudFront deployments take time to propagate. Do not diagnose a failed site immediately after apply while distribution status is still deploying.

## Mapping to PDF Deliverables

| PDF deliverable | Terraform evidence |
|---|---|
| IAM identity / least privilege | Out of scope: completed before this Terraform project |
| Bucket DNS-compliant name | Environment plan and S3 bucket name |
| Website file structure | `modules/static_website/site/` and S3 Objects console |
| Static website hosting enabled | `aws_s3_bucket_website_configuration` |
| CloudFront deployed | Distribution console; `cloudfront_url` output |
| Public website, private bucket | HTTPS CloudFront page plus S3 `AccessDenied` evidence |
| Cleanup | Destroy output and absence of environment resources |

## Cost and Safety Notes

- CloudFront, S3 storage, S3 requests, data transfer, Route 53 hosted zones, and ACM usage can incur charges depending on usage and configuration. Review the AWS pricing pages and the existing budget before deployment.
- A Route 53 hosted zone remains chargeable until it is deleted.
- Prefer the CloudFront `PriceClass_100` setting for a small training site, unless global edge coverage is a requirement.
- Remote state can contain resource identifiers and other sensitive metadata. Keep the state bucket private, encrypted, versioned, and restricted.
- Do not enable public S3 access as a troubleshooting shortcut.

## Cleanup Order

For an environment, run:

```bash
cd environments/dev
terraform destroy
```

Terraform normally handles dependency order, removing Route 53 records, CloudFront, site objects, and the website bucket in a safe order.

Do not destroy `bootstrap/` until all environments have been destroyed and remote state is no longer needed. Before deleting the remote backend, migrate state elsewhere or confirm that it is intentionally being retired.

## Documentation References

- [Terraform S3 backend](https://developer.hashicorp.com/terraform/language/backend/s3)
- [Amazon S3 static website hosting](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteHosting.html)
- [CloudFront OAC for private S3 origins](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html)
- [S3 security best practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
