package main

test_public_rds_denied {
	deny[_] with input as {"resource_changes": [{
		"type": "aws_db_instance",
		"name": "pg_shared01",
		"change": {"after": {"publicly_accessible": true}},
	}]}
}

test_private_rds_allowed {
	count(deny) == 0 with input as {"resource_changes": [{
		"type": "aws_db_instance",
		"name": "pg_shared01",
		"change": {"after": {"publicly_accessible": false}},
	}]}
}
