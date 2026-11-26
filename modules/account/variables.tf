variable "team_id" {
  description = "Stable team identifier stamped as metadata; authorization does not inspect this tag."
  type        = string
  nullable    = false
}

variable "team_name" {
  description = "Human-readable team name, used only as descriptive metadata."
  type        = string
  nullable    = false
}

variable "environment" {
  description = "Environment stamped on IAM resources."
  type        = string
  default     = "dev"
  nullable    = false
}

variable "platform_ci_role_arn" {
  description = "Explicit ARN of the shared CI role owned by platform state; may be in a different AWS account."
  type        = string
  nullable    = false
}

variable "role_name" {
  description = "Explicit name of the team's provisioning role."
  type        = string
  nullable    = false
}

variable "operator_arns" {
  description = "Exact IAM user or role ARNs allowed to assume this team's role, in addition to shared CI."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "aws_account_id" {
  description = "Shared AWS account that owns the authorized S3 buckets."
  type        = string
  nullable    = false
}

variable "aws_partition" {
  description = "AWS partition for resource ARN construction."
  type        = string
  default     = "aws"
  nullable    = false
}

variable "tags" {
  description = "Tags to apply to the IAM role."
  type        = map(string)
  default     = {}
  nullable    = false
}
