output "delegated_subnet_ids" {
  value = { for k, v in azurerm_subnet.delegated : k => v.id }
}

output "private_endpoint_subnet_id" {
  value = azurerm_subnet.private_endpoints.id
}

output "private_dns_zone_ids" {
  value = { for k, v in azurerm_private_dns_zone.this : k => v.id }
}
