# Contained databases: unlike Postgres/MySQL, SQL Server users are
# per-database (contained users), so there is no cross-database naming
# collision and no `<db>_` prefixing scheme is needed (ADR 0004 —
# documented there explicitly so the Postgres convention isn't
# copy-pasted somewhere it doesn't apply).
resource "azurerm_mssql_database" "this" {
  for_each = var.databases

  name            = each.key
  server_id        = var.server_id
  elastic_pool_id  = var.elastic_pool_id
  sku_name         = var.elastic_pool_id != null ? null : each.value.sku_name
  max_size_gb       = each.value.max_size_gb
  zone_redundant    = each.value.tier == "tier1"

  short_term_retention_policy {
    retention_days = var.backup_retention_days
  }

  long_term_retention_policy {
    weekly_retention  = each.value.tier == "tier1" ? "P4W" : "P0D"
    monthly_retention = each.value.tier == "tier1" ? "P12M" : "P0D"
    yearly_retention  = each.value.tier == "tier1" ? "P7Y" : "P0D"
    week_of_year      = 1
  }

  tags = merge(var.tags, {
    team                = each.value.team
    "backup-tier"       = each.value.tier
    "data-classification" = each.value.data_classification
  })

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_database_extended_auditing_policy" "this" {
  for_each                = var.databases
  database_id              = azurerm_mssql_database.this[each.key].id
  log_monitoring_enabled    = true
}
