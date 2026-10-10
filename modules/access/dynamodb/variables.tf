variable "table_arn" {
  type = string
}

variable "table_kms_key_arn" {
  type = string
}

variable "principals" {
  description = "Map of principal (IAM role name) => { role = rw|ro, leading_keys = optional(list(string)) } for tenant isolation."
  type = map(object({
    role         = string
    leading_keys = optional(list(string), [])
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
