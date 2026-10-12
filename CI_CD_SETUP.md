# GitHub Actions Terraform Deployment

The workflow at `.github/workflows/terraform-deploy.yml` runs Terraform manually from
GitHub Actions. In GitHub, open **Actions**, select **Terraform deployment**, click
**Run workflow**, and choose:

- `dev`, `staging`, or `prod`
- `plan`, `apply`, or `destroy`

`apply` and `destroy` use the plan generated earlier in the same workflow run.

## One-time AWS setup

The workflow uses GitHub OpenID Connect (OIDC), so it does not need long-lived AWS
access keys. The `bootstrap` Terraform configuration provisions the repository's
deployment role and its policy. It also manages the existing GitHub OIDC provider
without allowing Terraform to delete it.

Apply bootstrap once using your local AWS profile:

```bash
make bootstrap-plan
make bootstrap-apply
```

The role trusts only deployment jobs from `Spomega/website_deployed_s3` that run in
the `dev`, `staging`, or `prod` GitHub Environment. Its permissions are scoped to the
Terraform state bucket, this project's expected S3 website buckets, and the explicit
CloudFront operations managed by this Terraform module.

Do not create long-lived AWS access keys for GitHub Actions.

## GitHub Environment setup

In the GitHub repository, create environments named `dev`, `staging`, and `prod`.
For each environment, add these **Variables**:

| Variable | Value |
| --- | --- |
| `AWS_ROLE_TO_ASSUME` | ARN of the IAM role created for GitHub Actions |
| `TF_STATE_BUCKET` | Existing Terraform remote-state bucket name |
| `AWS_REGION` | `eu-central-1` (optional; this is the default) |

Use GitHub Environment protection rules to require approval for `prod`. The selected
environment is applied to the workflow job, so its variables and approval rules are
used automatically.

## Local development

Local Terraform commands still use `aws_profile = "spomega"` by default. In GitHub
Actions, `TF_VAR_aws_profile` is set to an empty value and Terraform uses the temporary
OIDC credentials instead.
