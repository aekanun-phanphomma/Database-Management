# ADR 0006: Restore strategy

## Status
Accepted

## Context
Backup existing is not the same as restore working. The platform
spec treats restore as a first-class, regularly-drilled workflow
(section 13) rather than a wiki page DBAs follow from memory during an
incident — by the time an incident happens is the worst time to
discover a runbook step is wrong.

## Decision

**Always restore to a new resource, never in place** (ties directly
to [[0001-layering]]'s `prevent_destroy` posture — an in-place restore
would require destroying the thing `prevent_destroy` protects).

**Three modes**, chosen per request (`restores/*.yaml`, `spec.mode`):

| Mode | Engines | Mechanism |
|---|---|---|
| `full-server` | RDS/Aurora, PG/MySQL Flexible, Cosmos account, SQL MI | Native PITR to a brand-new server/account (`modules/restore/aws-rds-pitr`, `azure-pg-pitr`, `cosmos-pitr`). Restores *every* database on that server. |
| `single-db` | Postgres/MySQL (dump/restore via a temporary full-server restore), Azure SQL DB (native per-database PITR, no temp server needed), Cosmos (restore into new account, copy out), DynamoDB (native table-level PITR) | See `scripts/restore-single-db-pg.sh` and `modules/restore/azure-sql-db-pitr`/`dynamodb-pitr`. |
| `drill` | all | Same mechanism as `full-server`/`single-db`, but always auto-destroyed regardless of `ttl_hours`, and never gets an L3 access stack applied. |

**Why single-db is two different mechanisms per engine:** Postgres and
MySQL roles/grants are server-wide, and there is no native
per-database PITR — the temporary-server-then-dump/restore path in
[[restore-single-db]] exists *because* of that limitation, not out of
preference. Azure SQL DB and DynamoDB both have genuine native
per-database/per-table PITR, so they skip the temp-resource step
entirely (`modules/restore/azure-sql-db-pitr`, `dynamodb-pitr`).

**Every restored resource, regardless of mode:**
- Inherits the source's encryption, network placement, and data
  classification.
- Is tagged `purpose=restore` (or `restore-drill`), `restore-ticket=<id>`,
  `requested-by=<email>`, and `ttl=<absolute RFC3339 timestamp>` —
  computed once by the CI pipeline, never via Terraform's `timestamp()`,
  which would otherwise drift every plan.
- Is DBA-only until `scripts/validate-restore.sh` passes. L3 (access)
  is never applied to a restored resource directly — cutover happens
  by DNS swap, rename, or manual app reconfiguration (per
  `restores/*.yaml`'s `cutover` field), after which the *original*
  server's L3 stack continues to apply as normal.
- Gets destroyed by `cleanup-ttl.yml` once its `ttl` passes, whether or
  not anyone remembered to clean it up manually.

**Drills are the test suite for backups.** A backup that has never
been restored is unverified. `restore-drill.yml` runs on the cadence
set by `modules/_shared/backup-policy` per tier (monthly/quarterly/
semi-annual) and measures actual RTO against the tier's target —
failing the drill or exceeding RTO should open an issue automatically,
not wait for someone to notice in a dashboard.

## Consequences
- Two restore code paths exist for Postgres/MySQL (temp-server dump
  vs. native) depending on engine — this asymmetry is inherent to the
  engines, not a design inconsistency, and the runbooks name it
  explicitly so it isn't mistaken for one.
- A restore always costs at least one temporary resource's worth of
  spend for `full-server`/`single-db` modes until TTL cleanup runs;
  this is accepted as the price of "always a new resource, never
  in-place."
