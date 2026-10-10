include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/aws-backup"
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { key_arns = { backup = "arn:aws:kms:ap-southeast-1:000000000000:key/mock" } }
}

dependency "backup_policy" {
  config_path = "${get_repo_root()}/live/_shared/backup-policy"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { policy = { tier1 = { pitr_retention_days = 35, long_term_monthly = 12, long_term_yearly = 7, cross_region = true, cross_account_locked = true } } }
}

inputs = {
  name_prefix              = "${get_env("ORG_PREFIX", "acme")}-dev"
  backup_kms_key_arn       = dependency.kms.outputs.key_arns["backup"]
  tiers                    = dependency.backup_policy.outputs.policy
  dr_region                = "ap-southeast-2"
  backup_account_vault_arn = get_env("BACKUP_ACCOUNT_VAULT_ARN", "arn:aws:backup:ap-southeast-1:000000000000:backup-vault:TODO")
}
