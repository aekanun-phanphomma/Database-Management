# ADR 0004: Many databases per server — placement and blast-radius rules

## Status
Accepted

## Context
Running one database per server is the safest default but is not cost-
or ops-effective at scale. The platform needs to support many logical
databases on one server while keeping the blast radius of any one
team's request bounded and auditable.

On PostgreSQL/MySQL-family engines, several things are **server-scoped,
not database-scoped**: the CMK, the maintenance window, the major
engine version, backup/PITR, and failover. A restore or failover event
on a shared server affects every database on it, and a noisy-neighbor
workload can degrade every other tenant on the same server.

## Decision

**Placement rules**
- A server declares `allowed_classifications` and a `tier` (section
  13.1 of the spec). `restricted`-classified data always gets a
  dedicated server — never shared — because the server-scoped
  resources above would otherwise leak blast radius across
  classification boundaries.
- A shared server's effective tier is the **highest tier** of any
  database placed on it; L1 computes this from the inbound YAML
  requests rather than being set by hand, so it can't silently drift
  below what a tenant actually needs.
- Default cap: **20 databases per shared server**, enforced as a
  `precondition` in the L2 module (`modules/databases/*/guardrails.tf`),
  not just documented — a cap that only lives in a doc gets missed
  under deadline pressure.
- A connection budget (`server_max_connections - reserved_connections`)
  is enforced the same way, summing every database's
  `connection_limit`.

**Isolation inside one server**
- PostgreSQL: `REVOKE CONNECT ... FROM PUBLIC`, `REVOKE ALL ON SCHEMA
  public FROM PUBLIC`, and per-database NOLOGIN group roles
  (`<db>_owner`, `<db>_rw`, `<db>_ro`, `<db>_eng_ro`, `<db>_eng_rw`) —
  see section 10.2 of the spec. Roles are cluster-wide in Postgres, so
  the `<db>_` prefix is what actually prevents a payment-team role name
  from colliding with another team's role on the same cluster.
- SQL Server/Azure SQL: contained database users sidestep this problem
  entirely (users are per-database), so no name-prefixing scheme is
  needed there — documented explicitly so the Postgres convention
  isn't copy-pasted somewhere it doesn't apply.
- Cosmos DB: isolation via RBAC **scope** (`/dbs/<db>` or
  `/dbs/<db>/colls/<c>`), with dedicated throughput preferred for
  tier1 workloads so one tenant's hot partition can't starve another's.
- DynamoDB: one table per workload, one IAM policy per table; there is
  no "server" to share in the first place.

**Blast-radius rules for `for_each` loops**
- Always `for_each` over stable string keys (database name, principal
  name) for databases, roles, and grants. Never `count` — an
  index-keyed list reshuffles and deletes/recreates resources when an
  unrelated entry is added or removed earlier in the list.
- Renames go through `moved {}` blocks, never delete+recreate.
- Policy-as-code (`policies/`, see section 16.3 of the spec) blocks any
  `delete`/`replace` plan against `postgresql_database`,
  `azurerm_*_database`, `azurerm_cosmosdb_sql_database`/`container`,
  `aws_dynamodb_table`, servers, and keys, unless the PR carries a
  break-glass label and two DBA approvals.

## Consequences
- Requesters must pick a server at request time (`spec.server` in the
  YAML) and can be rejected by the capacity/classification
  preconditions — this is intentional friction, not a bug, and the
  README must explain the shared-server trade-off up front so teams
  aren't surprised by a rejected PR.
- The 20-database and connection-budget defaults are deliberately
  conservative starting points; raising them for a specific server is
  a reviewed Terraform change to that server's L1/L2 config, not a
  support ticket.
