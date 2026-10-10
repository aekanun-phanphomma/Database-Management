variable "server_fqdn" {
  type = string
}

variable "databases" {
  description = "Map of database name => { access = <same shape as DatabaseRequest.spec.access> }."
  type        = map(object({ access = any }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
