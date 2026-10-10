output "tags" {
  value = merge({
    "managed-by"          = "terraform"
    "repo"                = "db-platform"
    "env"                 = var.env
    "owner-team"          = var.owner_team
    "cost-center"         = var.cost_center
    "data-classification" = var.data_classification
    "tier"                = var.tier
  }, var.request != null ? { "request" = var.request } : {}, var.extra_tags)
}
