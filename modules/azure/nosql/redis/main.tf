# Entra ID data-plane RBAC (access policies) is the passwordless path for
# Azure Cache for Redis — access keys are left enabled at the resource
# level (the provider doesn't expose a "disable keys" switch the way
# Cosmos does) but access should be granted exclusively via
# azurerm_redis_cache_access_policy_assignment, never by handing out keys.
# TODO(verify): confirm redis_configuration block argument names
# (`enable_authentication` vs `aad_enabled` or similar) for azurerm ~> 4.0.
resource "azurerm_redis_cache" "this" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location             = var.location
  sku_name              = var.sku_name
  family                = var.family
  capacity              = var.capacity

  non_ssl_port_enabled         = false
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false

  redis_configuration {
    # TODO(verify): enable Entra authentication for this provider version's
    # redis_configuration block; argument name unconfirmed.
  }

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
    private_connection_resource_id = azurerm_redis_cache.this.id
    subresource_names              = ["redisCache"]
    is_manual_connection            = false
  }

  private_dns_zone_group {
    name                 = "redis-dns"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }

  tags = var.tags
}
