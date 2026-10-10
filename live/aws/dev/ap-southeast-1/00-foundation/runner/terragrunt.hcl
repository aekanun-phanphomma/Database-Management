include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/ci-runner-aws"
}

dependency "network" {
  config_path = "../network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { vpc_id = "vpc-mock", private_subnet_ids = ["subnet-mock1", "subnet-mock2"] }
}

inputs = {
  name_prefix  = "${get_env("ORG_PREFIX", "acme")}-dev"
  region       = "ap-southeast-1"
  vpc_id       = dependency.network.outputs.vpc_id
  private_subnet_ids = dependency.network.outputs.private_subnet_ids
  github_org   = get_env("GITHUB_ORG", "acme-org")
  github_repo  = get_env("GITHUB_REPO", "db-platform")
  runner_image = get_env("RUNNER_IMAGE_URI", "000000000000.dkr.ecr.ap-southeast-1.amazonaws.com/gh-runner:latest")
  l_layer_role_arns = {
    l0 = get_env("DEV_L0_ROLE_ARN", "arn:aws:iam::000000000000:role/id-dev-l0")
    l1 = get_env("DEV_L1_ROLE_ARN", "arn:aws:iam::000000000000:role/id-dev-l1")
    l2 = get_env("DEV_L2_ROLE_ARN", "arn:aws:iam::000000000000:role/id-dev-l2")
    l3 = get_env("DEV_L3_ROLE_ARN", "arn:aws:iam::000000000000:role/id-dev-l3")
  }
}
