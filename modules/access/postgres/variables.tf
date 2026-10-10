variable "cloud" {
  type = string
  validation {
    condition     = contains(["aws", "azure"], var.cloud)
    error_message = "cloud must be aws or azure."
  }
}

variable "databases" {
  description = "Same map as modules/databases/postgres, read from the same request inventory so access and database creation never drift apart."
  type = map(object({
    team   = string
    access = any
  }))
}

# --- Azure-only ---
variable "server_fqdn" {
  type    = string
  default = null
}

variable "tenant_id" {
  type    = string
  default = null
}

# --- AWS-only ---
variable "region" {
  type    = string
  default = null
}

variable "account_id" {
  type    = string
  default = null
}

variable "dbi_resource_id" {
  description = "RDS DbiResourceId or Aurora cluster resource id, used in the rds-db:connect ARN."
  type        = string
  default     = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
