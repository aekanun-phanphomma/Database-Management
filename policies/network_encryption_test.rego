package dbplatform.baseline

import rego.v1

test_public_rds_denied if {
	count(deny) > 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"after": {"publicly_accessible": true, "storage_encrypted": true}},
	}]}
}

test_private_encrypted_rds_allowed if {
	count(deny) == 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"after": {"publicly_accessible": false, "storage_encrypted": true}},
	}]}
}

test_unencrypted_rds_denied if {
	count(deny) > 0 with input as {"resource_changes": [{
		"address": "aws_db_instance.pg_shared01",
		"type": "aws_db_instance",
		"change": {"after": {"publicly_accessible": false, "storage_encrypted": false}},
	}]}
}

test_superuser_postgresql_role_denied if {
	count(deny) > 0 with input as {"resource_changes": [{
		"address": "postgresql_role.tf_admin",
		"type": "postgresql_role",
		"change": {"after": {"superuser": true}},
	}]}
}
