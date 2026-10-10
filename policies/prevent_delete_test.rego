package main

test_delete_without_break_glass_denied {
	deny[_] with input as {
		"break_glass_approved": false,
		"resource_changes": [{
			"type": "aws_db_instance",
			"name": "pg_shared01",
			"change": {"actions": ["delete"]},
		}],
	}
}

test_delete_with_break_glass_allowed {
	count(deny) == 0 with input as {
		"break_glass_approved": true,
		"resource_changes": [{
			"type": "aws_db_instance",
			"name": "pg_shared01",
			"change": {"actions": ["delete"]},
		}],
	}
}

test_unrelated_resource_delete_allowed {
	count(deny) == 0 with input as {
		"break_glass_approved": false,
		"resource_changes": [{
			"type": "aws_s3_bucket_policy",
			"name": "whatever",
			"change": {"actions": ["delete"]},
		}],
	}
}
