# Shared naming module (spec section 19: "Never hand-write names").
# Every live/ stack and every engine module should derive its resource
# name from this module's outputs instead of string-interpolating one
# locally — centralizing the convention here is what makes it possible
# to change the convention once instead of grep-and-replace everywhere.

variable "cloud" {
  type = string
  validation {
    condition     = contains(["aws", "azure"], var.cloud)
    error_message = "cloud must be aws or azure."
  }
}

variable "org_prefix" {
  type = string
}

variable "env" {
  type = string
  validation {
    condition     = contains(["dev", "uat", "prod"], var.env)
    error_message = "env must be dev, uat, or prod."
  }
}

variable "region_abbr" {
  description = "Short region code, e.g. sea for southeastasia / ap-southeast-1."
  type        = string
}

variable "resource_type" {
  description = "Logical resource kind, e.g. pg, mssql, cosmos, kv, rg, id, kms."
  type        = string
}

variable "purpose" {
  description = "Free-form distinguishing suffix, e.g. shared01, payment."
  type        = string
}
