include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/aws-kms"
}

inputs = {
  name_prefix    = "${get_env("ORG_PREFIX", "acme")}-dev"
  key_admin_arns = split(",", get_env("DEV_KMS_ADMIN_ARNS", "arn:aws:iam::TODO:role/id-dev-l0"))
  key_user_arns = {
    rds     = split(",", get_env("DEV_L1_ROLE_ARN", "arn:aws:iam::TODO:role/id-dev-l1"))
    secrets = split(",", get_env("DEV_L1_ROLE_ARN", "arn:aws:iam::TODO:role/id-dev-l1"))
    backup  = split(",", get_env("DEV_L0_ROLE_ARN", "arn:aws:iam::TODO:role/id-dev-l0"))
    logs    = split(",", get_env("DEV_L0_ROLE_ARN", "arn:aws:iam::TODO:role/id-dev-l0"))
  }
  break_glass_arns = split(",", get_env("DEV_BREAK_GLASS_ARNS", "arn:aws:iam::TODO:role/dba-break-glass"))
}
