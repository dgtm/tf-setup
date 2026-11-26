output "role_arn" {
  description = "ARN of the IAM role."
  value       = aws_iam_role.this.arn
}

output "permissions_boundary_arn" {
  description = "ARN of the managed permissions boundary attached to this role."
  value       = aws_iam_policy.permissions_boundary.arn
}
