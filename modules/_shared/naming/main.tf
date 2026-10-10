locals {
  # Azure CAF-style abbreviation prefixes (spec section 19).
  azure_prefix = {
    psql    = "psql"
    mssql   = "sql"
    sqldb   = "sqldb"
    mysql   = "mysql"
    cosmos  = "cosmos"
    kv      = "kv"
    rg      = "rg"
    id      = "id"
    redis   = "redis"
    cae     = "cae"
    caj     = "caj"
    law     = "law"
    ag      = "ag"
    bvault  = "bvault"
  }

  azure_name = "${lookup(local.azure_prefix, var.resource_type, var.resource_type)}-${var.org_prefix}-${var.env}-${var.region_abbr}-${var.purpose}"

  # AWS: <org>-<env>-<region>-<engine>-<name>
  aws_name = "${var.org_prefix}-${var.env}-${var.region_abbr}-${var.resource_type}-${var.purpose}"

  name = var.cloud == "azure" ? local.azure_name : local.aws_name
}
