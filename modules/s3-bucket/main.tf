data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_iam_session_context" "current" {
  arn = data.aws_caller_identity.current.arn
}


locals {
  config        = yamldecode(file(var.config_file))
  team_registry = yamldecode(file(abspath("${path.module}/../../configuration/teams.yml"))).teams
  team_role_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${local.team_registry[local.config.team_id].role_name}"
  buckets = {
    for id, bucket in local.config.buckets : id => {
      name_prefix        = "${bucket.name}-"
      allowed_role_arns  = setunion(toset([local.team_role_arn]), toset(try(bucket.allowed_role_arns, [])))
      public             = bucket.public
      versioning_enabled = try(bucket.versioning_enabled, true)
      force_destroy      = try(bucket.force_destroy, false)
      tags = merge({ Owner = local.config.team_id }, try(local.config.tags, {}), var.tags, try(bucket.tags, {}), {
        Environment = try(local.config.environment, "dev")
        ManagedBy   = "Terraform"
      })
    }
  }
}

locals {
  bucket_arns = { for id, bucket in aws_s3_bucket.this : id => bucket.arn }

  bucket_policies = {
    for id, bucket in local.buckets : id => {
      Version = "2012-10-17"
      Statement = concat([
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource  = [local.bucket_arns[id], "${local.bucket_arns[id]}/*"]
          Condition = { Bool = { "aws:SecureTransport" = "false" } }
        },
        merge({
          Sid       = "DenyOtherPrincipals"
          Effect    = "Deny"
          Principal = "*"
          Resource  = [local.bucket_arns[id], "${local.bucket_arns[id]}/*"]
          Condition = { StringNotEquals = { "aws:PrincipalArn" = sort(tolist(bucket.allowed_role_arns)) } }
        }, bucket.public ? { NotAction = ["s3:GetObject"] } : { Action = ["s3:*"] }),
        ], bucket.public ? [{
          Sid       = "AllowPublicRead"
          Effect    = "Allow"
          Principal = "*"
          Action    = "s3:GetObject"
          Resource  = "${local.bucket_arns[id]}/*"
      }] : [])
    }
  }
}


resource "aws_s3_bucket" "this" {
  for_each = local.buckets

  bucket_prefix = each.value.name_prefix
  force_destroy = each.value.force_destroy
  tags          = each.value.tags

  lifecycle {
    precondition {
      condition     = contains(each.value.allowed_role_arns, data.aws_iam_session_context.current.issuer_arn)
      error_message = "The provisioner has not assumed one of the configured team roles"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  block_public_acls       = true
  block_public_policy     = !each.value.public
  ignore_public_acls      = true
  restrict_public_buckets = !each.value.public
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  versioning_configuration {
    status = each.value.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each = local.buckets

  bucket = aws_s3_bucket.this[each.key].id

  depends_on = [aws_s3_bucket_public_access_block.this]
  policy     = jsonencode(local.bucket_policies[each.key])
}
