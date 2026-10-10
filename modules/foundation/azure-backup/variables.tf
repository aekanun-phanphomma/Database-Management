variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "immutability_state" {
  description = "Disabled | Unlocked | Locked. Use Unlocked during the grace period, then Locked for true immutability (spec section 3.8)."
  type        = string
  default     = "Unlocked"
}

variable "tags" {
  type    = map(string)
  default = {}
}
