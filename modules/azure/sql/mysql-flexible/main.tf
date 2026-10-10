# TODO(verify): Entra ID auth for MySQL Flexible Server
# (azurerm_mysql_flexible_server's `identity`/AAD-admin equivalent) is a
# newer capability than Postgres Flexible Server's — confirm the azurerm
# ~> 4.0 resource actually exposes an AAD-only mode before relying on it;
# if it doesn't yet, this falls back to ADR 0003 option 2/3 (engine-
# managed or rotation-owned secret) for the admin login.
ephemeral "random_password" "admin" {
  length  = 32
  special = true
}

resource "azurerm_mysql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location             = var.location
  version               = var.mysql_version
  sku_name              = var.sku_name

  administrator_login          = "dbmaster"
  administrator_password       = ephemeral.random_password.admin.result # TODO(verify): confirm write-only argument form for this provider version

  delegated_subnet_id = var.delegated_subnet_id
  private_dns_zone_id = var.private_dns_zone_id

  storage {
    size_gb = var.storage_gb
  }

  backup_retention_days        = var.backup_policy.pitr_retention_days
  geo_redundant_backup_enabled = var.backup_policy.geo_redundant

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cmk_identity_id]
  }

  customer_managed_key {
    key_vault_key_id          = var.cmk_versionless_key_id
    primary_user_assigned_identity_id = var.cmk_identity_id
  }

  dynamic "high_availability" {
    for_each = var.tier == "tier1" ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [zone]
  }
}

resource "azurerm_mysql_flexible_server_configuration" "require_tls" {
  name                = "require_secure_transport"
  resource_group_name = var.resource_group_name
  server_name          = azurerm_mysql_flexible_server.this.name
  value                 = "ON"
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-law"
  target_resource_id         = azurerm_mysql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
