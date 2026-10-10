# Required tags (spec section 19): owner-team, cost-center, env,
# data-classification, tier, managed-by=terraform, request, repo.
# Every taggable resource in live/ should merge this module's output
# into its `tags`/`Tags` argument instead of hand-assembling the map.

variable "owner_team" {
  type = string
}

variable "cost_center" {
  type = string
}

variable "env" {
  type = string
}

variable "data_classification" {
  type    = string
  default = "internal"
}

variable "tier" {
  type    = string
  default = "tier3"
}

variable "request" {
  description = "The requests/*.yaml ticket or metadata.name that caused this resource to exist; null for platform-owned (non-request-driven) resources."
  type        = string
  default     = null
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}
