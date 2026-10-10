# Standalone unit (deliberately NOT including live/root.hcl, whose
# cloud/env/region path-parsing assumes a live/<cloud>/<env>/<region>/...
# layout that this shared, cloud-agnostic unit doesn't fit). It wraps
# modules/_shared/backup-policy so other stacks can `dependency` on its
# outputs instead of hardcoding backup-tier numbers in multiple places.
terraform {
  source = "${get_repo_root()}/modules/_shared/backup-policy"
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket       = "${get_env("ORG_PREFIX", "acme")}-shared-tfstate"
    key          = "_shared/backup-policy/terraform.tfstate"
    region       = get_env("TF_STATE_REGION", "ap-southeast-1")
    encrypt      = true
    kms_key_id   = get_env("TF_STATE_KMS_KEY_ARN", null)
    use_lockfile = true
  }
}
