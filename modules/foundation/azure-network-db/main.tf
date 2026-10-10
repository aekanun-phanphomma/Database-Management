resource "azurerm_subnet" "delegated" {
  for_each = var.delegated_subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [each.value.address_prefix]

  delegation {
    name = "delegation"
    service_delegation {
      name = each.value.delegation_service_name
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = var.private_endpoint_subnet.name
  resource_group_name  = var.resource_group_name
  virtual_network_name = var.vnet_name
  address_prefixes     = [var.private_endpoint_subnet.address_prefix]
}

resource "azurerm_network_security_group" "delegated" {
  for_each            = var.delegated_subnets
  name                = "${var.name_prefix}-${each.key}-nsg"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "delegated" {
  for_each                  = var.delegated_subnets
  subnet_id                 = azurerm_subnet.delegated[each.key].id
  network_security_group_id = azurerm_network_security_group.delegated[each.key].id
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = toset(var.private_dns_zone_names)
  name                = each.key
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "spoke" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "${each.key}-to-${var.name_prefix}-spoke"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub" {
  for_each              = azurerm_private_dns_zone.this
  name                  = "${each.key}-to-hub"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = each.value.name
  virtual_network_id    = var.hub_vnet_id
  registration_enabled  = false
}
