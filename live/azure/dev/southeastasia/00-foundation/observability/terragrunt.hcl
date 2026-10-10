include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/azure-observability"
}

inputs = {
  name_prefix          = "${get_env("ORG_PREFIX", "acme")}-dev"
  resource_group_name = get_env("DEV_RG_NAME", "rg-acme-dev-db")
  location              = "southeastasia"
  action_group_email_receivers = [
    { name = "dba", email = get_env("DEV_DBA_EMAIL", "dba-team@example.com") }
  ]
}
