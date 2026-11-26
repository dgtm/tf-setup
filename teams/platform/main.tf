locals {
  ci_trust_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowSharedCI"
      Effect = "Allow"
      Principal = {
        Federated = "arn:${var.aws_partition}:iam::${var.aws_account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:${var.ci_repository}:ref:refs/heads/${var.ci_branch}"
        }
      }
    }]
  }

  ci_permissions_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeApprovedTeamRoles"
      Effect   = "Allow"
      Action   = ["sts:AssumeRole"]
      Resource = sort(values(local.team_role_arns))
    }]
  }
}

locals {
  teams = yamldecode(file("${path.module}/../../configuration/teams.yml")).teams

  accounts = {
    for team_id, team in local.teams : team.role_name => merge(team, { team_id = team_id })
  }

  # Construct target ARNs from the registry rather than role outputs so CI can
  # be created before the team roles that trust it, without a dependency cycle.
  team_role_arns = {
    for team_id, team in local.teams : team_id =>
    "arn:${var.aws_partition}:iam::${var.aws_account_id}:role/${team.role_name}"
  }
}

provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]
}

module "ci_role" {
  source = "../../modules/iam-role"

  role_name                   = "platform-ci"
  description                 = "Shared CI identity managed by the platform team"
  assume_role_policy          = jsonencode(local.ci_trust_policy)
  permissions_boundary_policy = jsonencode(local.ci_permissions_policy)
  policies = {
    assume-team-roles = jsonencode(local.ci_permissions_policy)
  }

  tags = merge({ Owner = "platform" }, var.tags, {
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# Key IAM instances by explicit role name so display/team label edits do not
# implicitly rename role resources or change their Terraform instance keys.
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
