variable "databases" {
  description = "Map of logical databases keyed by name. Mirrors modules/databases/postgres's shape; MySQL privileges are GRANT'd per-database directly (no cluster-wide role namespace collision risk the way Postgres roles have, since MySQL grants are table/db-scoped per user already)."
  type = map(object({
    team                = string
    data_classification = string
    tier                = string
    charset             = optional(string, "utf8mb4")
    collation           = optional(string, "utf8mb4_0900_ai_ci")
  }))

  validation {
    condition     = alltrue([for k, _ in var.databases : can(regex("^[a-z][a-z0-9_]{2,30}$", k))])
    error_message = "Database names must match ^[a-z][a-z0-9_]{2,30}$."
  }
}

variable "max_databases_per_server" {
  type    = number
  default = 20
}
