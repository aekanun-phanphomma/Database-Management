resource "terraform_data" "guardrails" {
  input = "guardrails"

  lifecycle {
    precondition {
      condition     = length(var.databases) <= var.max_databases_per_server
      error_message = "Too many databases on this server; request a new server (see ADR 0004)."
    }
  }
}
