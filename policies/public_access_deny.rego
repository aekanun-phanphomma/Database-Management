package main

# No public endpoints, anywhere (spec section 3.5 / capability contract
# in section 5). Checked against planned resource values, so this catches
# a bad default just as well as a deliberate override.

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "aws_db_instance"
	rc.change.after.publicly_accessible == true
	msg := sprintf("aws_db_instance.%s must not set publicly_accessible = true", [rc.name])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "azurerm_postgresql_flexible_server"
	rc.change.after.public_network_access_enabled == true
	msg := sprintf("azurerm_postgresql_flexible_server.%s must not set public_network_access_enabled = true", [rc.name])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "azurerm_mssql_server"
	rc.change.after.public_network_access_enabled == true
	msg := sprintf("azurerm_mssql_server.%s must not set public_network_access_enabled = true", [rc.name])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "azurerm_cosmosdb_account"
	rc.change.after.public_network_access_enabled == true
	msg := sprintf("azurerm_cosmosdb_account.%s must not set public_network_access_enabled = true", [rc.name])
}

deny[msg] {
	rc := input.resource_changes[_]
	rc.type == "azurerm_key_vault"
	rc.change.after.public_network_access_enabled == true
	msg := sprintf("azurerm_key_vault.%s must not set public_network_access_enabled = true", [rc.name])
}
