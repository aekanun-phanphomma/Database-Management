variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "retention_days" {
  type    = number
  default = 90
}

variable "action_group_email_receivers" {
  type    = list(object({ name = string, email = string }))
  default = []
}

variable "tags" {
  type    = map(string)
  default = {}
}
