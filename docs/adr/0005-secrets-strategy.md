# ADR 0005: Secrets strategy

## Status
Accepted — refines the ordering already set by [[0003-auth]].

## Context
ADR 0003 establishes that identity auth comes first and a password is
the exception. This ADR is the operational detail for the minority of
workloads that do need a secret: where it lives, who rotates it, and
what Terraform is and isn't allowed to touch.

## Decision

Four tiers, in strict preference order, never mixed within one
workload:

1. **Identity auth — no secret.** Entra ID / Managed Identity on
   Azure, IAM DB auth (`rds_iam`) on AWS, Cosmos RBAC, IAM policies for
   DynamoDB.
2. **Engine-managed secret.** `manage_master_user_password = true` on
   RDS/Aurora, handing lifecycle to Secrets Manager's built-in
   rotation. Reserved for the bootstrap admin account only — never for
   an application login.
3. **Rotation-owned secret.** Terraform creates the login
   role/user without ever setting its password (either omitting the
   argument or `lifecycle.ignore_changes = [password]`), plus the
   secret container and its rotation schedule. A separate rotation
   Lambda / Azure Function owns the actual value; it is never read
   back into Terraform state.
4. **Write-only bootstrap — last resort.** `ephemeral
   "random_password"` plus a provider write-only argument
   (`*_wo` / `*_wo_version`), bumped to rotate. Used only for a
   one-time legacy value that genuinely cannot do identity auth.

**What Terraform must never do**, regardless of tier:
- Store a plaintext password in a non-ephemeral resource attribute.
- Output a password, even marked `sensitive`.
- Read a tier-2/3 secret's current value back out after bootstrap —
  rotation functions own that value going forward.

**Where this already applies in the codebase:**
- `modules/aws/sql/rds-postgres`, `rds-mysql`, `rds-sqlserver`,
  `aurora-postgres`, `documentdb`: tier 2 (`manage_master_user_password`).
- `modules/aws/nosql/elasticache`: tier 3 — the AUTH token is read via
  `ephemeral "aws_secretsmanager_secret_version"`, never written to
  state (Redis has no identity-auth option at all).
- `modules/azure/sql/mssql-mi`, `mysql-flexible`: tier 4 — these
  resources require a bootstrap admin password argument with no
  AAD-only mode; generated via `ephemeral "random_password"`, marked
  `TODO(verify)` for write-only argument support per the pinned
  provider version.
- Everything else (Postgres Flexible/RDS/Aurora app auth, Azure SQL,
  Cosmos, DynamoDB): tier 1.

## Consequences
- A workload needing tier 3 or 4 must document *why* identity auth was
  not possible in its request PR — this is the enforcement mechanism,
  since nothing in Terraform itself can detect "this could have used
  identity auth but didn't."
- Rotation functions become part of the platform's operational
  surface (see [[rotate-secrets]] runbook) with their own on-call
  ownership, not something this repo's Terraform alone guarantees.
