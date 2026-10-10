# ADR 0001: Layered stacks (L0–L3), one stack per database server

## Status
Accepted

## Context
Terraform cannot `for_each` a `provider` block. Engine-level providers
(`postgresql`, `mssql`, `mysql`) each need a connection to one specific
server, so the server itself must be the state/provider boundary. Mixing
server-level (infra) and database-level (data-plane) resources in one
state also means a `terraform destroy` or careless `apply` on the data
plane can touch the server, and vice versa — too large a blast radius
for a platform other teams depend on.

## Decision
Split every server into four Terragrunt stacks, each with its own state
and its own pipeline identity:

| Layer | Path | Contents | Providers |
|---|---|---|---|
| L0 foundation | `live/<cloud>/<env>/<region>/00-foundation/*` | network, DNS, KMS/KV, backup vaults, observability, CI runners | aws / azurerm |
| L1 server | `servers/<s>/10-server` | server/cluster, parameters, HA, backup config, private endpoint | aws / azurerm |
| L2 databases | `servers/<s>/20-databases` | logical DBs, schemas, extensions, containers | engine provider + aws/azurerm |
| L3 access | `servers/<s>/30-access` | roles, grants, principals, secrets | engine provider + aws/azurerm |

Outputs flow one direction only: L0 → L1 → L2/L3, via Terragrunt
`dependency` blocks. `mock_outputs` are allowed only for `validate`/`plan`
on stacks that don't exist yet, never for `apply`.

Pipeline identities are scoped so that:
- L0's identity has broad infra rights but no DB data-plane rights.
- L1's identity can manage the server but not logical databases/grants.
- L2/L3's identities can manage data-plane objects but **cannot delete
  the server** (no `rds:DeleteDBInstance` / no `Microsoft.DBforPostgreSQL/flexibleServers/delete`).

L3 state is treated as sensitive (it contains role bindings and,
exceptionally, secret references) and is readable only by the L3
pipeline identity and the DBA break-glass group.

## Consequences
- More stacks to wire up per server (4 instead of 1), but each has a
  narrow, auditable blast radius.
- A server rename/move requires coordinated changes across layers;
  mitigated by `moved {}` blocks (see ADR 0004) and by keying L2/L3 on
  stable names, never on L1 resource addresses.
- Renaming or relocating a server is a deliberate, reviewed change —
  not a side effect of an unrelated database request.
