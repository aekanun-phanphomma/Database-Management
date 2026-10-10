output "name" {
  value = local.name
}

output "name_no_dashes" {
  description = "For resource types that forbid dashes (e.g. some Storage Account / Cosmos account naming rules)."
  value       = replace(local.name, "-", "")
}

# TODO(verify): Azure per-resource-type name length caps differ widely
# (Key Vault <= 24 chars, Storage Account <= 24 lowercase alphanumeric,
# Cosmos account <= 44, etc.) — this module does not truncate for you;
# callers must check their specific resource's limit before using
# `name` or `name_no_dashes` directly (see docs/architecture.md's
# naming convention table).
