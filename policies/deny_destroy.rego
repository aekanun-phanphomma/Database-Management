# Blocks delete/replace of protected resource types unless the plan's PR
# carried the break-glass label with two DBA approvals (spec section
# 10.4/16.3, ADR 0004). `data.exceptions.break_glass` is a map of
# resource address -> true, populated by the CI pipeline from the PR's
# labels/approvals before conftest runs — never set by a plan itself.
package dbplatform.destroy

import rego.v1

protected := {
	"aws_db_instance", "aws_rds_cluster", "aws_dynamodb_table", "aws_kms_key",
	"azurerm_postgresql_flexible_server", "azurerm_mssql_server", "azurerm_mssql_database",
	"azurerm_cosmosdb_account", "azurerm_cosmosdb_sql_database", "azurerm_cosmosdb_sql_container",
	"azurerm_key_vault", "azurerm_key_vault_key",
	"postgresql_database", "postgresql_schema",
}

deny contains msg if {
	rc := input.resource_changes[_]
	protected[rc.type]
	"delete" in rc.change.actions
	not data.exceptions.break_glass[rc.address]
	not data.exceptions.break_glass["*"] # apply.yml sets this when the merged PR carried [break-glass] + 2 approvals
	msg := sprintf("BLOCKED: %s would be deleted/replaced. Requires break-glass label + 2 DBA approvals.", [rc.address])
}
