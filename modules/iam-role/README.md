# IAM role module

Creates an IAM role, a managed permissions-boundary policy attached to that
role, and any supplied inline policies. This is the generic IAM building block
used by the platform root and the account module.

```hcl
module "role" {
  source = "../../modules/iam-role"

  role_name                   = "team-alpha-dev-storage"
  description                 = "Alpha provisioning role"
  assume_role_policy          = jsonencode(local.trust_policy)
  permissions_boundary_policy = jsonencode(local.boundary_policy)
  policies = {
    provision-buckets = jsonencode(local.provisioning_policy)
  }
  tags = {
    Owner = "team-001"
  }
}
```

## Inputs and outputs

Required inputs: `role_name`, `assume_role_policy`, `permissions_boundary_policy`,
and `tags`. The `tags` map must contain a nonempty `Owner` value. `description`
and `policies` are optional. Policy inputs are JSON strings; Terraform validates that trust and
boundary documents contain a `Statement` array and that each inline policy is
valid JSON.

Outputs:

- `role_arn`: ARN of the created role.
- `permissions_boundary_arn`: ARN of the created managed policy.

The module passes supplied tags through unchanged and requires callers to
provide `Owner`. The account module uses the team's ID as a fallback, while an
explicit `Owner` in registry tags takes precedence. The platform CI role uses
`Owner = "platform"` unless overridden by platform tags. `Owner` is metadata,
not an authorization control.
