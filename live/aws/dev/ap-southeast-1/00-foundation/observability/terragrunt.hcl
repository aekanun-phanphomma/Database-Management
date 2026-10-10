include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/aws-observability"
}

dependency "kms" {
  config_path = "../kms"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { key_arns = { logs = "arn:aws:kms:ap-southeast-1:000000000000:key/mock" } }
}

inputs = {
  name_prefix           = "${get_env("ORG_PREFIX", "acme")}-dev"
  logs_kms_key_arn      = dependency.kms.outputs.key_arns["logs"]
  log_group_names       = ["/rds/acme-dev-pg-shared01/postgresql"]
  alarm_email_endpoints = split(",", get_env("DEV_ALARM_EMAILS", "dba-team@example.com"))
}
