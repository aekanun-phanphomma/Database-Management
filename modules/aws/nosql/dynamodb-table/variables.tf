variable "name" {
  type = string
}

variable "hash_key" {
  type = string
}

variable "range_key" {
  type    = string
  default = null
}

variable "attributes" {
  description = "Map of attribute name => type (S | N | B)."
  type        = map(string)
}

variable "billing_mode" {
  type    = string
  default = "PAY_PER_REQUEST"
}

variable "global_secondary_indexes" {
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = optional(string)
    projection_type = string
  }))
  default = []
}

variable "kms_key_arn" {
  type = string
}

variable "tier" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
