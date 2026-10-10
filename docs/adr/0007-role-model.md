# ADR 0007: Standard role model

## Status
Accepted

## Context
Six engines (Postgres, MySQL, SQL Server, Cosmos, DynamoDB, Redis)
each have their own native permission model. Without a forced common
vocabulary, every engine module would invent its own tier names, and
a requester moving a workload from one engine to another would have
to relearn the access model from scratch.

## Decision

Every engine implements the same six semantic tiers, even though the
underlying mechanism differs completely per engine:

| Tier | Purpose | Who | Auth |
|---|---|---|---|
| `owner` | Owns schemas, runs DDL | migration identity only | MI / IAM |
| `rw` | DML | application | MI / IAM |
| `ro` | read | reporting, read replicas | MI / IAM |
| `eng_ro` | read for engineers | Entra / IdC group | SSO + token |
| `eng_rw` | break-glass write | PIM-eligible group only | SSO + PIM |
| `dba_admin` | server admin | `grp-dba-admins` | SSO |

**Apps never run as `owner`.** The platform creates the `owner` role
and binds only the migration identity (Flyway/Liquibase/EF) to it —
see the "out of scope" boundary in the top-level goals: this platform
owns roles and grants, not table/schema DDL, and `owner` is the seam
between the two.

**Per-engine mechanism**, all implementing the same six tiers:

- **Postgres** (`modules/databases/postgres`, `access/postgres`):
  NOLOGIN group roles `<db>_<tier>`, prefixed per database because
  Postgres roles are cluster-wide (see [[0004-shared-servers]]).
  Login principals bind to a group role via `GRANT <group> TO <login>`.
- **MySQL** (`access/mysql`): no cluster-wide namespace collision
  risk, so grants attach directly to `user@host` without a group-role
  indirection layer.
- **SQL Server** (`access/mssql`): contained database roles
  `role_<tier>`, scoped per database natively — no `<db>_` prefix
  needed (SQL Server users are already per-database).
- **Cosmos DB** (`access/cosmos-nosql`): the two built-in data-plane
  RBAC role definitions (Reader, Contributor) stand in for `ro`/`rw`;
  `owner`/`eng_rw`/`eng_ro` collapse onto whichever of the two actually
  grants the needed permission, since Cosmos's native model only has
  two tiers at the data plane.
- **DynamoDB** (`access/dynamodb`): IAM policy actions per tier
  (`ro` = Get/Query/Scan/DescribeTable, `rw` = ro + Put/Update/Delete/
  BatchWrite), with optional `dynamodb:LeadingKeys` for `eng_ro`/`eng_rw`
  style per-tenant scoping.

**`eng_rw` is always time-bound.** The requesting group must be
PIM-eligible-only (Azure) or an IAM Identity Center permission set
activated per-session (AWS) — a standing `eng_rw` assignment defeats
the point and should be flagged in request review.

## Consequences
- An engine whose native model doesn't cleanly map to six tiers
  (Cosmos, DynamoDB) ends up with some tiers sharing a mechanism — this
  is documented per engine in its access module rather than forcing a
  fictitious six-way distinction the engine doesn't actually support.
- Anyone auditing "who can write to this database" asks the same six
  questions regardless of engine, which is the actual payoff of this
  ADR — the mechanism differs, the question doesn't.
