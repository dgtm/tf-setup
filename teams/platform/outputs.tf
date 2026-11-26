output "ci_role_arn" {
  description = "Shared CI role ARN to trust from each team's account module."
  value       = module.ci_role.role_arn
}

output "permissions_boundary_arn" {
  description = "Boundary limiting CI to assuming registered team roles."
  value       = module.ci_role.permissions_boundary_arn
}

output "team_roles" {
  description = "Team identities and boundaries owned exclusively by platform state."
  value = {
    for team_id, team in local.teams : team_id => {
      role_arn                 = module.accounts[team.role_name].role_arn
      permissions_boundary_arn = module.accounts[team.role_name].permissions_boundary_arn
    }
  }
}
