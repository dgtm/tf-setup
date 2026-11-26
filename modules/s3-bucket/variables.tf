variable "config_file" {
  description = "Path to the team YAML. The module decodes its contents."
  type        = string
  nullable    = false

  validation {
    condition = try(
      length(trimspace(yamldecode(file(var.config_file)).team_id)) > 0 &&
      length(keys(yamldecode(file(var.config_file)).buckets)) > 0 &&
      alltrue([for bucket in values(yamldecode(file(var.config_file)).buckets) :
        length(trimspace(bucket.name)) > 0 &&
        can(bucket.public) &&
        (bucket.public == true || bucket.public == false)
      ]),
      false,
    )
    error_message = "Team YAML must define team_id, a nonempty buckets map, and each bucket's name and public boolean."
  }
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
  nullable    = false
}



