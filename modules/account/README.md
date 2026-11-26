# Account module

Creates one team's provisioning role and its permissions boundary. The platform
Terraform root calls this module once for every entry in
`configuration/teams.yml`:

```hcl
module "accounts" {
  source   = "../../modules/account"
  for_each = local.accounts

  team_id              = each.value.team_id
  team_name            = each.value.name
  role_name            = each.value.role_name
  environment          = try(each.value.environment, var.environment)
  platform_ci_role_arn = module.ci_role.role_arn
  operator_arns        = try(each.value.operator_arns, [])

  aws_account_id = var.aws_account_id
  aws_partition  = var.aws_partition
  tags           = try(each.value.tags, {})
}
```

## Inputs and outputs

Required inputs are `team_id`, `team_name`, `role_name`, `platform_ci_role_arn`,
and `aws_account_id`. `operator_arns` optionally adds exact IAM user or role
principals allowed to assume the team role. `environment`, `aws_partition`, and
`tags` have defaults.

Outputs:

- `role_arn`: ARN of the team's provisioning role.
- `permissions_boundary_arn`: ARN of the boundary attached to that role.

## Permissions

The module trusts the shared platform CI role and the configured operators.
Its inline policy allows S3 bucket setup and object operations, plus `iam:GetRole`
on the team's own role for the S3 module's assumed-role check. It does not grant
IAM administration or permission to assume another team's role.

The permissions boundary caps the role to S3 provisioning actions. It also
denies access to buckets in other AWS accounts when AWS provides the resource
account context. The team role's identity policy uses broad bucket ARN patterns;
the S3 module installs a per-bucket resource policy to restrict each bucket to
the owning role and any explicitly listed additional roles.

This is a single-account boundary. The team role can change policies on its own
buckets, and IAM administrators and the account root remain trusted. Avoid
creating team buckets outside the S3 module, since they would not receive the
module's bucket policy.
