resource "azurerm_postgresql_flexible_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  version             = var.pg_version
  sku_name            = var.sku_name
  storage_mb          = var.storage_mb
  auto_grow_enabled   = true

  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false

  backup_retention_days        = var.backup_policy.pitr_retention_days
  geo_redundant_backup_enabled = var.backup_policy.geo_redundant

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = compact([var.cmk_identity_id, var.geo_cmk_identity_id])
  }

  customer_managed_key {
    key_vault_key_id                     = var.cmk_versionless_key_id
    primary_user_assigned_identity_id    = var.cmk_identity_id
    geo_backup_key_vault_key_id          = var.backup_policy.geo_redundant ? var.geo_cmk_versionless_key_id : null
    geo_backup_user_assigned_identity_id = var.backup_policy.geo_redundant ? var.geo_cmk_identity_id : null
  }

  dynamic "high_availability" {
    for_each = var.tier == "tier1" ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [zone, high_availability[0].standby_availability_zone]
  }
}

locals {
  server_parameters = merge({
    require_secure_transport = "on"
    ssl_min_protocol_version = "TLSv1.2"
    shared_preload_libraries = "pg_stat_statements,pgaudit"
    "pgaudit.log"            = "ddl,role"
    log_connections          = "on"
    log_disconnections       = "on"
    "azure.extensions"       = upper(join(",", sort(var.allowed_extensions)))
  }, var.extra_parameters)
}

resource "azurerm_postgresql_flexible_server_configuration" "this" {
  for_each  = local.server_parameters
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "dba" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id            = var.tenant_id
  object_id            = var.dba_group_object_id
  principal_name       = var.dba_group_name
  principal_type       = "Group"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "pipeline_l3" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id            = var.tenant_id
  object_id            = var.pipeline_l3_object_id
  principal_name       = var.pipeline_l3_name
  principal_type       = "ServicePrincipal"
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-law"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "audit"
  }
  enabled_log {
    category_group = "allLogs"
  }

  # TODO(verify): azurerm ~> 4.0 — confirm whether azurerm_monitor_diagnostic_setting
  # uses `enabled_metric { category = "AllMetrics" }` or the older `metric { ... }`
  # block shape for this provider version (spec section 12.1 flags this explicitly).
  enabled_metric {
    category = "AllMetrics"
  }
}
