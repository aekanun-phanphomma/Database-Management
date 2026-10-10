resource "azurerm_cosmosdb_account" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location             = var.location
  offer_type            = "Standard"
  kind                  = "GlobalDocumentDB"

  # Disabling local auth forces every client onto RBAC (spec section 11.5)
  # — no connection-string/key access path exists once this is true.
  local_authentication_disabled = true
  public_network_access_enabled  = false
  minimal_tls_version              = "Tls12"

  consistency_policy {
    consistency_level = "Session" # TODO(verify): confirm against actual workload requirements; Session is the Cosmos default, not necessarily right for every tier
  }

  dynamic "geo_location" {
    for_each = var.geo_locations
    content {
      location          = geo_location.value.location
      failover_priority = geo_location.value.failover_priority
    }
  }

  backup {
    type = "Continuous"
    tier = var.continuous_backup_tier
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cmk_identity_id]
  }

  default_identity_type = "UserAssignedIdentity=${var.cmk_identity_id}"
  key_vault_key_id        = var.cmk_versionless_key_id

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_private_endpoint" "this" {
  name                = "pe-${var.name}"
  resource_group_name = var.resource_group_name
  location             = var.location
  subnet_id            = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_cosmosdb_account.this.id
    subresource_names              = ["Sql"]
    is_manual_connection            = false
  }

  private_dns_zone_group {
    name                 = "cosmos-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-law"
  target_resource_id         = azurerm_cosmosdb_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
  enabled_metric {
    category = "Requests"
  }
}
