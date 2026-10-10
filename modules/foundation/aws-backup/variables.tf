variable "name_prefix" {
  type = string
}

variable "backup_kms_key_arn" {
  type = string
}

variable "tiers" {
  description = "Backup policy per tier, normally dependency-wired from modules/_shared/backup-policy."
  type = map(object({
    pitr_retention_days  = number
    long_term_monthly    = number
    long_term_yearly      = number
    cross_region         = bool
    cross_account_locked = bool
  }))
}

variable "dr_region" {
  type = string
}

variable "backup_account_vault_arn" {
  description = "ARN of the vault in the isolated backup account (Vault Lock, compliance mode). Required for cross_account_locked tiers."
  type        = string
}

variable "resource_type_tag_key" {
  description = "Tag key used to assign resources to backup plans via selection."
  type        = string
  default     = "backup-tier"
}

variable "enable_vault_lock" {
  description = "Set true only when deploying this module INTO the isolated backup account/subscription (spec section 3.8: Vault Lock, compliance mode)."
  type        = bool
  default     = false
}

variable "vault_lock_min_retention_days" {
  type    = number
  default = 7
}

variable "vault_lock_max_retention_days" {
  type    = number
  default = 2555 # ~7 years, covers tier1 yearly x 7
}

variable "vault_lock_changeable_for_days" {
  description = "Cooling-off period before compliance mode becomes irreversible. null disables the grace period."
  type        = number
  default     = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
