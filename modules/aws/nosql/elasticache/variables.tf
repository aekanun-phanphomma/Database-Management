variable "name" {
  type = string
}

variable "engine" {
  type    = string
  default = "valkey" # TODO(verify): confirm "valkey" vs "redis" engine string support for the pinned aws ~> 6.0 provider version
}

variable "engine_version" {
  type    = string
  default = "7.2"
}

variable "node_type" {
  type = string
}

variable "num_cache_clusters" {
  type    = number
  default = 2
}

variable "subnet_group_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "ingress_security_group_ids" {
  type = list(string)
}

variable "kms_key_arn" {
  type = string
}

variable "auth_token_secret_arn" {
  description = "Secrets Manager ARN holding the AUTH token — Redis has no native identity auth, so this is an ADR 0003 exception (option 3, rotation-owned secret)."
  type        = string
}

variable "tier" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}
