package dbplatform.tagging

import rego.v1

full_tags := {
	"managed-by": "terraform",
	"repo": "db-platform",
	"env": "dev",
	"owner-team": "payment-team",
	"cost-center": "CC-1234",
	"data-classification": "confidential",
	"tier": "tier1",
}

test_fully_tagged_resource_allowed if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"actions": ["create"], "after": {"tags": full_tags}},
	}]}
}

test_missing_tags_denied if {
	count(deny) > 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"actions": ["create"], "after": {"tags": {"managed-by": "terraform"}}},
	}]}
}

test_delete_action_not_checked if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"actions": ["delete"], "after": {}},
	}]}
}
