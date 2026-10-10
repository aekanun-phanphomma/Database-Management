variable "server_id" {
  type = string
}

variable "elastic_pool_id" {
  type    = string
  default = null
}

variable "databases" {
  type = map(object({
    team                = string
    data_classification = string
    tier                = string
    max_size_gb          = optional(number, 10)
    sku_name             = optional(string, "GP_S_Gen5_2")
  }))

  validation {
    condition     = alltrue([for k, _ in var.databases : can(regex("^[a-z][a-zA-Z0-9_]{2,60}$", k))])
    error_message = "Database names must match ^[a-z][a-zA-Z0-9_]{2,60}$."
  }
}

variable "backup_retention_days" {
  type = number
}

variable "tags" {
  type    = map(string)
  default = {}
}
