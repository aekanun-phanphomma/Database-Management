include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/azure-backup"
}

inputs = {
  name_prefix          = "${get_env("ORG_PREFIX", "acme")}-dev"
  resource_group_name = get_env("DEV_RG_NAME", "rg-acme-dev-db")
  location              = "southeastasia"
  immutability_state    = "Unlocked" # flip to "Locked" after the grace period per spec section 3.8
}
