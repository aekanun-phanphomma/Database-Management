# Unit tests for the capacity/classification guardrails (spec section
# 17.1). Run from the module root: `terraform test`. Lives inside the
# module (not top-level tests/) per spec section 19's module layout
# ("every module has versions.tf, variables.tf, main.tf, outputs.tf,
# README.md, and tests/").
mock_provider "postgresql" {}

variables {
  server_max_connections         = 200
  reserved_connections           = 20
  max_databases_per_server       = 20
  server_allowed_classifications = ["internal", "confidential"]
  databases = {
    payment = { team = "payment", data_classification = "confidential", tier = "tier1", connection_limit = 100, access = {} }
    order   = { team = "order", data_classification = "internal", tier = "tier2", connection_limit = 50, access = {} }
  }
}

run "creates_five_group_roles_per_db" {
  command = plan
  assert {
    condition     = length(postgresql_role.group) == 10
    error_message = "Expected 5 tiers x 2 databases."
  }
}

run "rejects_connection_budget_overflow" {
  command = plan
  variables {
    databases = {
      a = { team = "t", data_classification = "internal", tier = "tier3", connection_limit = 150, access = {} }
      b = { team = "t", data_classification = "internal", tier = "tier3", connection_limit = 150, access = {} }
    }
  }
  expect_failures = [terraform_data.guardrails]
}

run "rejects_restricted_on_shared_server" {
  command = plan
  variables {
    databases = {
      hr = { team = "hr", data_classification = "restricted", tier = "tier1", connection_limit = 10, access = {} }
    }
  }
  expect_failures = [terraform_data.guardrails]
}

run "rejects_too_many_databases" {
  command = plan
  variables {
    max_databases_per_server = 1
    databases = {
      a = { team = "t", data_classification = "internal", tier = "tier3", connection_limit = 10, access = {} }
      b = { team = "t", data_classification = "internal", tier = "tier3", connection_limit = 10, access = {} }
    }
  }
  expect_failures = [terraform_data.guardrails]
}

run "adding_one_database_does_not_change_existing_keys" {
  command = plan
  assert {
    condition     = contains(keys(postgresql_role.group), "payment_owner")
    error_message = "Existing database's group role keys must stay stable when another database is added (spec section 17.1: key stability)."
  }
  assert {
    condition     = contains(keys(postgresql_role.group), "order_owner")
    error_message = "Existing database's group role keys must stay stable when another database is added."
  }
}
