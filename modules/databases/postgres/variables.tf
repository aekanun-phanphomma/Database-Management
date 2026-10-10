variable "databases" {
  description = "Map of logical databases keyed by name, assembled by the live/ stack from matching requests/*.yaml files."
  type = map(object({
    team                = string
    data_classification = string
    tier                = string
    connection_limit    = optional(number, 50)
    extensions          = optional(list(string), [])
    schemas             = optional(list(string), ["app"])
    access              = any
  }))

  validation {
    condition     = alltrue([for k, _ in var.databases : can(regex("^[a-z][a-z0-9_]{2,30}$", k))])
    error_message = "Database names must match ^[a-z][a-z0-9_]{2,30}$."
  }
}

variable "server_max_connections" {
  description = "From L1 output. 0 means 'unknown at plan time' (Azure Flexible Server) — guardrail is skipped with a warning in that case."
  type        = number
}

variable "reserved_connections" {
  type = number
}

variable "server_allowed_classifications" {
  type = list(string)
}

variable "max_databases_per_server" {
  type = number
}
