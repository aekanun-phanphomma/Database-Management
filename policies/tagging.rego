package main

# Every taggable resource carries the minimum tag set from
# docs/architecture.md's naming convention table.

required_tags := {"managed-by", "repo", "env"}

taggable_types := {
	"aws_db_instance",
	"aws_rds_cluster",
	"aws_dynamodb_table",
	"aws_kms_key",
	"azurerm_postgresql_flexible_server",
	"azurerm_mssql_server",
	"azurerm_cosmosdb_account",
	"azurerm_key_vault",
}

deny[msg] {
	rc := input.resource_changes[_]
	taggable_types[rc.type]
	rc.change.actions != ["delete"]
	tags := object.get(rc.change.after, "tags", {})
	missing := required_tags - {k | tags[k]}
	count(missing) > 0
	msg := sprintf("%s.%s is missing required tags: %v", [rc.type, rc.name, missing])
}
