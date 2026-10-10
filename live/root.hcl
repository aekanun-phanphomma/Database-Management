locals {
  path_parts = split("/", path_relative_to_include())
  cloud      = local.path_parts[0]
  env        = local.path_parts[1]
  region     = local.path_parts[2]

  org_prefix = get_env("ORG_PREFIX", "acme")

  common_tags = {
    managed-by = "terraform"
    repo       = "db-platform"
    org        = local.org_prefix
    env        = local.env
    cloud      = local.cloud
  }
}

remote_state {
  backend = local.cloud == "aws" ? "s3" : "azurerm"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = local.cloud == "aws" ? {
    bucket       = "${local.org_prefix}-${local.env}-tfstate"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    kms_key_id   = get_env("TF_STATE_KMS_KEY_ARN")
    use_lockfile = true
    } : {
    resource_group_name  = "rg-${local.env}-tfstate"
    storage_account_name = "st${local.org_prefix}${local.env}tfstate"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}

generate "provider_aws" {
  path      = "provider_aws.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.cloud == "aws" ? <<-EOF
    provider "aws" {
      region = "${local.region}"
      default_tags {
        tags = ${jsonencode(local.common_tags)}
      }
    }
  EOF
  : ""
}

generate "provider_azurerm" {
  path      = "provider_azurerm.tf"
  if_exists = "overwrite_terragrunt"
  contents  = local.cloud == "azure" ? <<-EOF
    provider "azurerm" {
      features {}
    }
  EOF
  : ""
}

inputs = {
  org_prefix  = local.org_prefix
  env         = local.env
  cloud       = local.cloud
  region      = local.region
  common_tags = local.common_tags
}
