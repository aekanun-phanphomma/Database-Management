# terraform test for modules/databases/postgres's capacity/classification
# guardrails (spec section 10.3). Run with: terraform test -test-directory=tests
# from the module directory, or `terraform test` at the module root with
# this file symlinked/copied into modules/databases/postgres/tests/.
#
# The postgresql provider is mocked so this test never attempts a real
# network connection — only the guardrails preconditions are exercised.
mock_provider "postgresql" {}

run "connection_budget_within_limit_passes" {
  command = plan

  variables {
    databases = {
      payment = {
        team                = "payment-team"
        data_classification = "confidential"
        tier                = "tier1"
        connection_limit    = 50
        extensions          = []
        schemas             = ["app"]
        access = {
          apps      = []
          migration = { principal = "mi-payment-migrator" }
          engineers = []
        }
      }
    }
    server_max_connections         = 200
    reserved_connections           = 10
    server_allowed_classifications = ["internal", "confidential"]
    max_databases_per_server       = 20
  }

  assert {
    condition     = true
    error_message = "plan should succeed when connection budget and classification are within limits"
  }
}

run "connection_budget_exceeded_fails" {
  command = plan

  variables {
    databases = {
      payment = {
        team                = "payment-team"
        data_classification = "confidential"
        tier                = "tier1"
        connection_limit    = 500
        extensions          = []
        schemas             = ["app"]
        access = {
          apps      = []
          migration = { principal = "mi-payment-migrator" }
          engineers = []
        }
      }
    }
    server_max_connections         = 200
    reserved_connections           = 10
    server_allowed_classifications = ["internal", "confidential"]
    max_databases_per_server       = 20
  }

  expect_failures = [terraform_data.guardrails]
}

run "disallowed_classification_fails" {
  command = plan

  variables {
    databases = {
      payment = {
        team                = "payment-team"
        data_classification = "restricted"
        tier                = "tier1"
        connection_limit    = 50
        extensions          = []
        schemas             = ["app"]
        access = {
          apps      = []
          migration = { principal = "mi-payment-migrator" }
          engineers = []
        }
      }
    }
    server_max_connections         = 200
    reserved_connections           = 10
    server_allowed_classifications = ["internal", "confidential"]
    max_databases_per_server       = 20
  }

  expect_failures = [terraform_data.guardrails]
}
