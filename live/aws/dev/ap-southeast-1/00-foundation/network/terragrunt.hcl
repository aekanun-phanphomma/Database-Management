include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/aws-network-db"
}

# NOTE: vpc_id / subnet CIDRs / route tables below are placeholders — this
# module assumes an existing VPC (created by a separate network landing-zone
# stack, out of scope for this platform repo). Fill in real values per
# environment before the first real apply.
inputs = {
  name_prefix             = "${get_env("ORG_PREFIX", "acme")}-dev"
  vpc_id                  = get_env("DEV_VPC_ID", "vpc-TODO")
  vpc_cidr                = get_env("DEV_VPC_CIDR", "10.0.0.0/16")
  availability_zones      = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  private_subnet_cidrs    = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
  private_route_table_ids = split(",", get_env("DEV_PRIVATE_RT_IDS", "rtb-TODO1,rtb-TODO2,rtb-TODO3"))
  runner_cidr_blocks      = ["10.0.200.0/24"]
  private_dns_zone_name   = "db.dev.internal"
}
