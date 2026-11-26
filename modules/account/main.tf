locals {
  role_arn = "arn:${var.aws_partition}:iam::${var.aws_account_id}:role/${var.role_name}"

  # Create/tag-on-create can run before resource-account context exists.
  bootstrap_actions = ["s3:CreateBucket", "s3:TagResource"]
  bucket_actions = [
    "s3:GetBucket*",
    "s3:GetEncryptionConfiguration",
    "s3:GetLifecycleConfiguration",
    "s3:GetReplicationConfiguration",
    "s3:GetAccelerateConfiguration",
    "s3:ListBucket",
    "s3:ListBucketVersions",
    "s3:ListBucketMultipartUploads",
    "s3:DeleteBucket",
    "s3:PutBucketPolicy",
    "s3:DeleteBucketPolicy",
    "s3:PutBucketPublicAccessBlock",
    "s3:PutBucketOwnershipControls",
    "s3:PutBucketVersioning",
    "s3:PutEncryptionConfiguration",
    "s3:UntagResource",
    "s3:ListTagsForResource",
  ]
  object_actions = [
    "s3:GetObject",
    "s3:GetObjectVersion",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:DeleteObjectVersion",
    "s3:AbortMultipartUpload",
    "s3:ListMultipartUploadParts",
  ]
  account_condition = {
    StringEquals = { "s3:ResourceAccount" = var.aws_account_id }
  }

  # Other teams' bucket policies deny this role, including policy changes.
  provisioning_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "CreateBuckets"
        Effect   = "Allow"
        Action   = local.bootstrap_actions
        Resource = ["arn:${var.aws_partition}:s3:::*"]
      },
      {
        Sid       = "ManageTeamBuckets"
        Effect    = "Allow"
        Action    = local.bucket_actions
        Resource  = ["arn:${var.aws_partition}:s3:::*"]
        Condition = local.account_condition
      },
      {
        Sid       = "AccessTeamObjects"
        Effect    = "Allow"
        Action    = local.object_actions
        Resource  = ["arn:${var.aws_partition}:s3:::*/*"]
        Condition = local.account_condition
      },
      {
        Sid      = "ResolveOwnSessionRole"
        Effect   = "Allow"
        Action   = ["iam:GetRole"]
        Resource = [local.role_arn]
      },
    ]
  }

  permissions_boundary_policy = {
    Version = "2012-10-17"
    Statement = concat(local.provisioning_policy.Statement, [
      {
        Sid       = "DenyActionsOutsideProvisioning"
        Effect    = "Deny"
        NotAction = concat(local.bootstrap_actions, local.bucket_actions, local.object_actions, ["iam:GetRole"])
        Resource  = "*"
      },
      {
        Sid      = "DenyOtherBucketAccounts"
        Effect   = "Deny"
        Action   = "s3:*"
        Resource = "*"
        Condition = {
          StringNotEquals = { "s3:ResourceAccount" = var.aws_account_id }
          Null            = { "s3:ResourceAccount" = "false" }
        }
      },
    ])
  }
}

locals {
  assume_role_policy = {
    Version = "2012-10-17"
    Statement = concat([
      {
        Sid    = "AllowPlatformCI"
        Effect = "Allow"
        Principal = {
          AWS = var.platform_ci_role_arn
        }
        Action = "sts:AssumeRole"
      },
      ], length(var.operator_arns) > 0 ? [{
        Sid       = "AllowTeamOperators"
        Effect    = "Allow"
        Principal = { AWS = sort(tolist(var.operator_arns)) }
        Action    = "sts:AssumeRole"
    }] : [])
  }
}

module "team_role" {
  source = "../iam-role"

  role_name                   = var.role_name
  description                 = "Provision ${var.team_name} team S3 buckets"
  assume_role_policy          = jsonencode(local.assume_role_policy)
  permissions_boundary_policy = jsonencode(local.permissions_boundary_policy)
  tags = merge({ Owner = var.team_id }, var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
  policies = {
    provision-buckets = jsonencode(local.provisioning_policy)
  }
}
