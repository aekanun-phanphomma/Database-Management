include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "${get_repo_root()}/modules/foundation/azure-keyvault"
}

dependency "network" {
  config_path = "../network"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    private_endpoint_subnet_id = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/virtualNetworks/mock/subnets/mock"
    private_dns_zone_ids       = { "privatelink.vaultcore.azure.net" = "/subscriptions/mock/resourceGroups/mock/providers/Microsoft.Network/privateDnsZones/mock" }
  }
}

inputs = {
  name_prefix                = "${get_env("ORG_PREFIX", "acme")}-dev"
  resource_group_name        = get_env("DEV_RG_NAME", "rg-acme-dev-db")
  location                    = "southeastasia"
  tenant_id                   = get_env("AZURE_TENANT_ID", "00000000-0000-0000-0000-000000000000")
  private_endpoint_subnet_id  = dependency.network.outputs.private_endpoint_subnet_id
  private_dns_zone_id         = dependency.network.outputs.private_dns_zone_ids["privatelink.vaultcore.azure.net"]
  admin_object_ids            = split(",", get_env("DEV_KV_ADMIN_OIDS", "00000000-0000-0000-0000-000000000000"))
}
