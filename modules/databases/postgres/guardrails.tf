# Capacity and policy guardrails as code (spec section 10.3). These run at
# plan time and fail the apply outright rather than relying on a human
# reviewer to notice a server is over budget.
resource "terraform_data" "guardrails" {
  input = "guardrails"

  lifecycle {
    precondition {
      condition = (
        var.server_max_connections == 0 ||
        sum(concat([0], [for d in var.databases : d.connection_limit])) <= var.server_max_connections - var.reserved_connections
      )
      error_message = "Sum of database connection_limit exceeds server budget (max_connections - reserved_connections)."
    }

    precondition {
      condition     = length(var.databases) <= var.max_databases_per_server
      error_message = "Too many databases on this server; request a new server (see ADR 0004)."
    }

    precondition {
      condition = alltrue([
        for d in var.databases : contains(var.server_allowed_classifications, d.data_classification)
      ])
      error_message = "A database's data_classification is not allowed on this server (see ADR 0004 — restricted data never shares a server)."
    }
  }
}
