variable "aws_partition" {
  description = "AWS partition containing the platform account."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*$", var.aws_partition))
    error_message = "aws_partition must be a lowercase AWS partition name."
  }
}

variable "aws_account_id" {
  description = "Twelve-digit AWS account ID managed by the platform root."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "aws_account_id must contain exactly 12 digits."
  }
}

variable "aws_region" {
  description = "AWS region used by the platform provider."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]*-[0-9]+$", var.aws_region))
    error_message = "aws_region must be a lowercase AWS region name."
  }
}

variable "environment" {
  description = "Environment name applied to platform-managed resources."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]{0,15}$", var.environment))
    error_message = "environment must start with a lowercase letter and contain at most 16 lowercase letters, digits, underscores, or hyphens."
  }
}

variable "tags" {
  description = "Additional tags applied to platform-managed resources."
  type        = map(string)
  default     = {}
  nullable    = false
}

variable "ci_repository" {
  description = "GitHub owner/repository allowed to authenticate as the shared CI role."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.ci_repository))
    error_message = "ci_repository must be a GitHub owner/repository pair."
  }
}

variable "ci_branch" {
  description = "Branch allowed to authenticate as the shared CI role."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._/-]*$", var.ci_branch))
    error_message = "ci_branch must be a branch name without wildcards."
  }
}
