package dbplatform.destroy

import rego.v1

test_delete_without_break_glass_denied if {
	count(deny) > 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"actions": ["delete"]},
	}]}
		with data.exceptions.break_glass as {}
}

test_delete_with_break_glass_exception_allowed if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"actions": ["delete"]},
	}]}
		with data.exceptions.break_glass as {"aws_db_instance.pg_shared01": true}
}

test_delete_with_wildcard_break_glass_allowed if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"actions": ["delete"]},
	}]}
		with data.exceptions.break_glass as {"*": true}
}

test_unrelated_resource_delete_allowed if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_s3_bucket_policy.whatever",
		"type": "aws_s3_bucket_policy",
		"change": {"actions": ["delete"]},
	}]}
		with data.exceptions.break_glass as {}
}
