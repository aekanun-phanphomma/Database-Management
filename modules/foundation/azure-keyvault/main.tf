data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = "kv-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = var.tenant_id
  sku_name            = "premium" # required for HSM-backed keys used by CMK encryption

  # TODO(verify): confirm the exact attribute name for the pinned azurerm
  # ~> 4.0 version — rbac_authorization_enabled vs enable_rbac_authorization
  # has changed across azurerm major versions (spec section 8.2 flags this
  # explicitly as needing verification).
  rbac_authorization_enabled   = true
  purge_protection_enabled     = true
  soft_delete_retention_days   = 90
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

  tags = var.tags
}

resource "azurerm_role_assignment" "admins" {
  for_each             = toset(var.admin_object_ids)
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = each.key
}

resource "azurerm_private_endpoint" "kv" {
  name                = "pe-kv-${var.name_prefix}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-kv-${var.name_prefix}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "kv-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}

resource "azurerm_key_vault_key" "this" {
  for_each     = toset(var.purposes)
  name         = "cmk-${each.key}"
  key_vault_id = azurerm_key_vault.this.id
  key_type     = "RSA"
  key_size     = 3072
  key_opts     = ["decrypt", "encrypt", "sign", "unwrapKey", "verify", "wrapKey"]

  rotation_policy {
    automatic {
      time_before_expiry = "P30D"
    }
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"
  }

  depends_on = [azurerm_role_assignment.admins]
}
