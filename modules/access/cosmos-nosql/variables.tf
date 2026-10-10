variable "account_id" {
  type = string
}

variable "account_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "databases" {
  description = "Map of database name => { access = <DatabaseRequest.spec.access shape> }."
  type        = map(object({ access = any }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
