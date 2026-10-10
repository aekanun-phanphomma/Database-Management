package main

# Blocks delete/replace of protected resource types unless the plan's PR
# carried the break-glass label with two DBA approvals (spec section
# 10.4 / 16.3, ADR 0004). conftest is given a `terraform show -json`
# plan plus an external `break_glass` input (set by apply.yml from the
# PR's labels/approvals) merged into the input document.

protected_types := {
	"postgresql_database",
	"azurerm_postgresql_flexible_server",
	"azurerm_mssql_database",
	"azurerm_cosmosdb_sql_database",
	"azurerm_cosmosdb_sql_container",
	"aws_db_instance",
	"aws_rds_cluster",
	"aws_dynamodb_table",
	"aws_kms_key",
	"azurerm_key_vault",
	"azurerm_key_vault_key",
}

deny[msg] {
	rc := input.resource_changes[_]
	protected_types[rc.type]
	some action in rc.change.actions
	action == "delete"
	not input.break_glass_approved
	msg := sprintf(
		"delete of protected resource %s.%s requires the break-glass label and two DBA approvals (see docs/runbooks/break-glass.md)",
		[rc.type, rc.name],
	)
}

deny[msg] {
	rc := input.resource_changes[_]
	protected_types[rc.type]
	rc.change.actions == ["delete", "create"]
	not input.break_glass_approved
	msg := sprintf(
		"replace (delete+create) of protected resource %s.%s requires the break-glass label and two DBA approvals",
		[rc.type, rc.name],
	)
}
