include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/ci-runner-azure"
}

dependency "network" {
  config_path = "../network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { delegated_subnet_ids = {}, private_endpoint_subnet_id = "/subscriptions/mock/.../subnets/mock" }
}

inputs = {
  name_prefix          = "${get_env("ORG_PREFIX", "acme")}-dev"
  resource_group_name = get_env("DEV_RG_NAME", "rg-acme-dev-db")
  location              = "southeastasia"
  runner_subnet_id      = get_env("DEV_RUNNER_SUBNET_ID", "/subscriptions/TODO/.../subnets/snet-runner")
  runner_image          = get_env("RUNNER_IMAGE_URI", "mcr.microsoft.com/TODO/gh-runner:latest")
  github_org            = get_env("GITHUB_ORG", "acme-org")
  github_repo           = get_env("GITHUB_REPO", "db-platform")
  l_layer_app_registration_ids = {
    l0 = get_env("DEV_L0_APP_OID", "00000000-0000-0000-0000-000000000000")
    l1 = get_env("DEV_L1_APP_OID", "00000000-0000-0000-0000-000000000000")
    l2 = get_env("DEV_L2_APP_OID", "00000000-0000-0000-0000-000000000000")
    l3 = get_env("DEV_L3_APP_OID", "00000000-0000-0000-0000-000000000000")
  }
}
