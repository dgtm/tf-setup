# S3 bucket module

Creates all buckets declared in one team's YAML file, along with the supporting
S3 controls and bucket policies. The team Terraform root passes the YAML path:

```hcl
module "buckets" {
  source = "../../modules/s3-bucket"

  config_file = local.config_file
  tags = {
    Owner = "team-001" # Optional; defaults to team_id from the YAML.
  }
}
```

## Input configuration

`config_file` points to a team YAML file. Each bucket must set `public` to
`true` or `false`; it controls anonymous object reads for that bucket. Optional
`tags` adds tags from the calling team, including `Owner`. If no supplied tag
sets `Owner`, it defaults to the team's `team_id`. The module reads
`configuration/teams.yml` from this repository to resolve the role name
registered for the YAML's `team_id`.

The repository preflight validates the YAML against the team JSON Schema before
the Terraform runner starts and reports file-level errors.

Run the module's Terraform validation test with `make s3-module-test` (Terraform
1.7 or later for mocked AWS provider support).

```yaml
team_id: team-001
aws_region: eu-central-1
environment: dev
tags:
  Project: alpha-storage
buckets:
  assets:
    name: assets
    public: false
  reports:
    name: reports
    public: true
    allowed_role_arns:
      - arn:aws:iam::123456789012:role/alpha-reports-reader
```

The `buckets` map is keyed by stable Terraform identifiers. Each entry requires
a `name` base and may include:

| Setting | Default | Effect |
| --- | --- | --- |
| `public` | Required | Allows anonymous HTTPS `GetObject` requests when `true` |
| `allowed_role_arns` | `[]` | Adds exact IAM role ARNs to this bucket's access policy; the registered team role is always included |
| `versioning_enabled` | `true` | Enables bucket versioning |
| `force_destroy` | `false` | Allows Terraform to delete nonempty buckets when enabled |
| `tags` | `{}` | Adds bucket tags, merged over team-level tags |

## Behavior and access controls

- The output `buckets` map is keyed by the YAML bucket identifiers. Each value
  has `id`, `arn`.
- All buckets use `BucketOwnerEnforced` ownership controls, block public ACLs, use
  server-side encryption, and a policy requiring HTTPS.
- `Owner` defaults to the team ID and can be overridden by team YAML tags, module `tags`, and
  bucket YAML tags in order.

## Caveat

The module owns `aws_s3_bucket_policy` for its buckets. Do not manage another
bucket policy for the same bucket in the calling root: S3 supports one policy
per bucket, and Terraform resources would overwrite each other. 

Future optimization would be to have a check on the plan output and reject destruction of the default policy.
