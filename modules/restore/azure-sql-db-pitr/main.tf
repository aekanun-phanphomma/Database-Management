# Azure SQL DB's native per-database PITR means single-db mode (spec
# section 13.3) doesn't need the dump/restore workaround that
# scripts/restore-single-db-pg.sh exists for on Postgres/MySQL — this
# resource restores exactly one database, to a new database name, same
# or different server, directly.
resource "azurerm_mssql_database" "restored" {
  name      = "${basename(var.source_database_id)}-r${var.restore_tag}"
  server_id = var.target_server_id
  sku_name   = var.sku_name

  create_mode                = "PointInTimeRestore"
  creation_source_database_id = var.source_database_id
  restore_point_in_time        = var.restore_point_in_time

  tags = merge(var.tags, {
    purpose          = "restore"
    "restore-ticket" = var.ticket
    "requested-by"   = var.requested_by
    ttl              = var.ttl_at_utc
  })
}
