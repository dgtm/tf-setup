variable "role_name" {
  description = "Name of the IAM role."
  type        = string
  nullable    = false
}

variable "description" {
  description = "Description of the IAM role."
  type        = string
  default     = null
}

variable "assume_role_policy" {
  description = "IAM trust policy as JSON with a Statement array."
  type        = string
  nullable    = false

  validation {
    condition     = can(concat([], jsondecode(var.assume_role_policy).Statement))
    error_message = "assume_role_policy must be a JSON policy document with a Statement array (which may be empty)."
  }
}

variable "permissions_boundary_policy" {
  description = "JSON policy defining the maximum identity-based permissions for this role."
  type        = string
  nullable    = false

  validation {
    condition     = can(concat([], jsondecode(var.permissions_boundary_policy).Statement))
    error_message = "permissions_boundary_policy must be a JSON policy document with a Statement array."
  }
}

variable "policies" {
  description = "JSON inline policies keyed by policy name, limited by the permissions boundary."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for policy in values(var.policies) : can(jsondecode(policy))])
    error_message = "Every inline policy must be valid JSON."
  }
}

variable "tags" {
  description = "Tags to apply to the IAM role; must include a nonempty Owner value."
  type        = map(string)
  nullable    = false

  validation {
    condition     = can(var.tags["Owner"]) && try(length(trimspace(var.tags["Owner"])) > 0, false)
    error_message = "tags must include a nonempty Owner value."
  }
}
