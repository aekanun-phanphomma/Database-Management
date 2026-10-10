resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "dba" {
  name                = "ag-${var.name_prefix}-dba"
  resource_group_name = var.resource_group_name
  short_name          = substr("dba${var.name_prefix}", 0, 12)

  dynamic "email_receiver" {
    for_each = var.action_group_email_receivers
    content {
      name          = email_receiver.value.name
      email_address = email_receiver.value.email
    }
  }

  tags = var.tags
}
