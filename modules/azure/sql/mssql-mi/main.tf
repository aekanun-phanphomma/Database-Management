# SQL Managed Instance — used for workloads needing SQL Server feature
# parity (cross-database queries, CLR, Service Broker) that Azure SQL DB
# doesn't support. Heavier and slower to provision (hours, not minutes)
# than azurerm_mssql_server; most new workloads should prefer
# modules/azure/sql/mssql-server unless MI-specific features are needed.
#
# administrator_login_password is a required argument on this resource
# (no AAD-only mode exists for the instance-level SQL admin, unlike
# Flexible Server) — ADR 0003 option 4 applies: generate it ephemerally
# and never let it land in state. Day-to-day auth should still go through
# the azuread_administrator block below, not this bootstrap account.
ephemeral "random_password" "mi_admin" {
  length  = 32
  special = true
}

resource "azurerm_mssql_managed_instance" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location             = var.location
  subnet_id            = var.delegated_subnet_id

  license_type        = "LicenseIncluded"
  sku_name              = var.sku_name
  vcores                = var.vcores
  storage_size_in_gb     = var.storage_size_gb

  administrator_login          = "dbmaster"
  administrator_login_password = ephemeral.random_password.mi_admin.result # TODO(verify): confirm whether a write-only argument form (administrator_login_password_wo) exists for this resource on azurerm ~> 4.0 instead of passing the ephemeral value directly

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cmk_identity_id]
  }

  minimum_tls_version = "1.2"

  tags = merge(var.tags, { "backup-tier" = var.tier })

  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_mssql_managed_instance_active_directory_administrator" "dba" {
  managed_instance_id = azurerm_mssql_managed_instance.this.id
  login_username       = var.dba_group_name
  object_id             = var.dba_group_object_id
  tenant_id             = var.tenant_id
}

resource "azurerm_mssql_managed_instance_transparent_data_encryption" "this" {
  managed_instance_id = azurerm_mssql_managed_instance.this.id
  key_vault_key_id     = var.cmk_versionless_key_id
}
