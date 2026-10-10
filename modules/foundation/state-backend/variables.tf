variable "cloud" {
  type = string
  validation {
    condition     = contains(["aws", "azure"], var.cloud)
    error_message = "cloud must be aws or azure."
  }
}

variable "name_prefix" {
  description = "e.g. acme-prod. Used to derive the bucket/storage account name."
  type        = string
}

# --- AWS ---
variable "tfstate_kms_key_arn" {
  type    = string
  default = null
}

# --- Azure ---
variable "resource_group_name" {
  type    = string
  default = null
}

variable "location" {
  type    = string
  default = null
}

variable "tfstate_cmk_key_vault_key_id" {
  type    = string
  default = null
}

variable "tfstate_cmk_identity_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}
