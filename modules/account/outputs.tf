output "role_arn" {
  description = "ARN of the team's provisioning role."
  value       = module.team_role.role_arn
}

output "permissions_boundary_arn" {
  description = "ARN of the team's permissions boundary."
  value       = module.team_role.permissions_boundary_arn
}
