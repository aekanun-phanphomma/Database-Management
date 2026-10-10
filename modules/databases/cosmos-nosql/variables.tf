variable "account_name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "databases" {
  description = "Map of database name => { team, data_classification, tier, containers = map(name => { partition_key_path, dedicated_throughput_rus (null = shared) }) }."
  type = map(object({
    team                = string
    data_classification = string
    tier                = string
    containers = map(object({
      partition_key_path        = string
      dedicated_throughput_rus  = optional(number)
    }))
  }))
}

variable "shared_throughput_rus" {
  description = "Database-level shared throughput, used only when a container has no dedicated_throughput_rus (spec section 10.2: prefer dedicated for tier1)."
  type        = number
  default     = 400
}

variable "tags" {
  type    = map(string)
  default = {}
}
