variable "name_prefix" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "runner_subnet_id" {
  type = string
}

variable "runner_image" {
  type = string
}

variable "github_org" {
  type = string
}

variable "github_repo" {
  type = string
}

variable "l_layer_app_registration_ids" {
  description = "Map layer (l0..l3) => Entra app registration object id to federate GitHub OIDC credentials to."
  type        = map(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
