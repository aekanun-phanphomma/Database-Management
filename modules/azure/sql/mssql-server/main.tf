resource "azurerm_mssql_server" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location             = var.location
  version              = "12.0"

  azuread_administrator {
    azuread_authentication_only = true
    login_username               = var.dba_group_name
    object_id                    = var.dba_group_object_id
    tenant_id                    = var.tenant_id
  }

  minimum_tls_version            = "1.2"
  public_network_access_enabled  = false

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cmk_identity_id]
  }

  primary_user_assigned_identity_id = var.cmk_identity_id

  tags = var.tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_server_transparent_data_encryption" "this" {
  server_id        = azurerm_mssql_server.this.id
  key_vault_key_id = var.cmk_versionless_key_id
}

resource "azurerm_mssql_server_extended_auditing_policy" "this" {
  server_id                              = azurerm_mssql_server.this.id
  log_monitoring_enabled                  = true
  # TODO(verify): azurerm ~> 4.0 — confirm whether storage_endpoint/
  # storage_account_access_key are still required alongside
  # log_monitoring_enabled, or whether LAW-only auditing is sufficient.
}

resource "azurerm_mssql_server_security_alert_policy" "this" {
  resource_group_name = var.resource_group_name
  server_name          = azurerm_mssql_server.this.name
  state                 = "Enabled"
}

resource "azurerm_mssql_server_vulnerability_assessment" "this" {
  server_security_alert_policy_id = azurerm_mssql_server_security_alert_policy.this.id
  storage_container_path          = "" # TODO(verify): requires a storage container path per azurerm docs; wire to a dedicated assessment storage account
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.name}"
  resource_group_name = var.resource_group_name
  location             = var.location
  subnet_id            = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_mssql_server.this.id
    subresource_names              = ["sqlServer"]
    is_manual_connection            = false
  }

  private_dns_zone_group {
    name                 = "mssql-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_mssql_elasticpool" "this" {
  count               = var.elastic_pool != null ? 1 : 0
  name                = "${var.name}-pool"
  resource_group_name = var.resource_group_name
  location             = var.location
  server_name          = azurerm_mssql_server.this.name
  max_size_gb           = var.elastic_pool.max_size_gb

  sku {
    name     = var.elastic_pool.sku_name
    tier     = "GeneralPurpose" # TODO(verify): derive from sku_name instead of hardcoding
    family   = "Gen5"
    capacity = 2
  }

  per_database_settings {
    min_capacity = 0
    max_capacity = 2 # TODO(verify): size per actual per-database contention tolerance, not a flat default
  }

  tags = var.tags
}

# TODO(verify): Azure SQL diagnostic categories are typically exposed at
# the DATABASE resource level (azurerm_mssql_database), not the logical
# server — confirm whether this server-level diagnostic setting is valid
# or whether it needs to move to modules/databases/mssql per database.
resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-law"
  target_resource_id         = azurerm_mssql_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}
