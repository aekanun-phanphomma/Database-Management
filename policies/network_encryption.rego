# No public endpoints and no unencrypted storage, ever (spec section
# 3.5 / capability contract in section 5).
package dbplatform.baseline

import rego.v1

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "aws_db_instance"
	after := rc.change.after
	after.publicly_accessible == true
	msg := sprintf("%s: publicly_accessible must be false", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "aws_db_instance"
	rc.change.after.storage_encrypted != true
	msg := sprintf("%s: storage_encrypted must be true", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type in {"azurerm_postgresql_flexible_server", "azurerm_mssql_server", "azurerm_cosmosdb_account"}
	rc.change.after.public_network_access_enabled == true
	msg := sprintf("%s: public network access must be disabled", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "postgresql_role"
	rc.change.after.superuser == true
	msg := sprintf("%s: superuser roles are forbidden", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "aws_elasticache_replication_group"
	rc.change.after.transit_encryption_enabled != true
	msg := sprintf("%s: transit_encryption_enabled must be true", [rc.address])
}

deny contains msg if {
	rc := input.resource_changes[_]
	rc.type == "azurerm_key_vault"
	rc.change.after.public_network_access_enabled == true
	msg := sprintf("%s: public network access must be disabled", [rc.address])
}
