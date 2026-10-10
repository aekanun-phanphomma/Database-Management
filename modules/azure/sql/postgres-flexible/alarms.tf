# Metrics alerts (capability contract, spec section 5). Mirrors
# modules/aws/sql/rds-postgres/alarms.tf's coverage: CPU, storage,
# connections. Needs an action_group_id, which the live/ stack must pass
# in from modules/foundation/azure-observability's output — threaded
# through as a new variable rather than silently reusing
# log_analytics_workspace_id.
variable "action_group_id" {
  type = string
}

resource "azurerm_monitor_metric_alert" "cpu_high" {
  name                = "${var.name}-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.this.id]
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "cpu_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 85
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "storage_low" {
  name                = "${var.name}-storage-low"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.this.id]
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "storage_percent"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 90
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags
}

resource "azurerm_monitor_metric_alert" "connections_high" {
  name                = "${var.name}-connections-high"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_postgresql_flexible_server.this.id]
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"

  criteria {
    metric_namespace = "Microsoft.DBforPostgreSQL/flexibleServers"
    metric_name      = "active_connections"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 400 # TODO(verify): size against the actual sku's connection ceiling instead of a flat default
  }

  action {
    action_group_id = var.action_group_id
  }

  tags = var.tags
}
