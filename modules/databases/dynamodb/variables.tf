variable "tables" {
  description = "Map of table name => { hash_key, range_key, attributes, global_secondary_indexes, tier }. Unlike the relational engines, DynamoDB has no shared-server concept (spec section 10.2), so each request maps 1:1 to its own table rather than being placed on a shared server."
  type = map(object({
    hash_key  = string
    range_key = optional(string)
    attributes = map(string)
    global_secondary_indexes = optional(list(object({
      name            = string
      hash_key        = string
      range_key       = optional(string)
      projection_type = string
    })), [])
    tier = string
  }))
}

variable "kms_key_arn" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
