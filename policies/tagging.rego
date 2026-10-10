# Minimum required tag set (spec section 19): managed-by, repo, env,
# owner-team, cost-center, data-classification, tier.
#
# TODO: modules/_shared/tagging produces this exact tag set, but most
# live/ stacks still pass through a plain var.tags map rather than
# this module's output — until every stack is retrofitted, this policy
# will correctly fail plans that are missing owner-team/cost-center/
# data-classification. That is the policy doing its job, not a bug in
# the policy.
package dbplatform.tagging

import rego.v1

required_tags := {"managed-by", "repo", "env", "owner-team", "cost-center", "data-classification", "tier"}

taggable_types := {
	"aws_db_instance", "aws_rds_cluster", "aws_dynamodb_table", "aws_kms_key",
	"azurerm_postgresql_flexible_server", "azurerm_mssql_server",
	"azurerm_cosmosdb_account", "azurerm_key_vault",
}

deny contains msg if {
	rc := input.resource_changes[_]
	taggable_types[rc.type]
	rc.change.actions != ["delete"]
	tags := object.get(rc.change.after, "tags", {})
	missing := required_tags - {k | tags[k]}
	count(missing) > 0
	msg := sprintf("%s is missing required tags: %v", [rc.address, missing])
}
