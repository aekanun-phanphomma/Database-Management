variable "cloud" {
  type = string
  validation {
    condition     = contains(["aws", "azure"], var.cloud)
    error_message = "cloud must be aws or azure."
  }
}

variable "databases" {
  type = map(object({ access = any }))
}

variable "tags" {
  type    = map(string)
  default = {}
}
