include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/azure-network-db"
}

# NOTE: vnet_id/hub_vnet_id are placeholders — this module assumes an
# existing hub-spoke VNet (owned by the connectivity subscription,
# out of scope for this repo). Fill in real values per environment.
inputs = {
  name_prefix         = "${get_env("ORG_PREFIX", "acme")}-dev"
  resource_group_name = get_env("DEV_RG_NAME", "rg-acme-dev-db")
  location             = "southeastasia"
  vnet_id              = get_env("DEV_VNET_ID", "/subscriptions/TODO/resourceGroups/TODO/providers/Microsoft.Network/virtualNetworks/TODO")
  vnet_name            = get_env("DEV_VNET_NAME", "vnet-acme-dev-db")
  hub_vnet_id          = get_env("HUB_VNET_ID", "/subscriptions/TODO/resourceGroups/TODO/providers/Microsoft.Network/virtualNetworks/vnet-hub")

  delegated_subnets = {
    "snet-pgflex" = {
      address_prefix          = "10.1.1.0/24"
      delegation_service_name = "Microsoft.DBforPostgreSQL/flexibleServers"
    }
  }

  private_endpoint_subnet = {
    name           = "snet-pe"
    address_prefix = "10.1.2.0/24"
  }
}
