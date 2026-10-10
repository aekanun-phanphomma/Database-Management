# Runbook: full-server restore

Use when server-level corruption, a region issue, or a DR event
requires restoring an entire server/cluster/account. See
[[0006-restore-strategy]] and the broader [restore-postgres](restore-postgres.md)
runbook for the Postgres-specific version of this; this file covers
the engine-agnostic shape.

## When this mode applies

- RDS/Aurora, Postgres/MySQL Flexible Server, Cosmos DB account, SQL
  Managed Instance — anything where the spec's `full-server` mode
  (section 13.3) is listed as supported.
- **Every database on the server comes back.** If only one tenant's
  data needs rolling back on an otherwise-healthy shared server, use
  [restore-single-db.md](restore-single-db.md) instead — restoring the
  whole server for a one-tenant problem affects every other tenant on
  it unnecessarily.

## Procedure

1. Open `restores/<name>.yaml` with `mode: full-server`, get two DBA
   approvals (prod).
2. CI applies the matching `modules/restore/*` module
   (`aws-rds-pitr`, `azure-pg-pitr`, `cosmos-pitr`, or the MI
   equivalent) to a **new** resource — never in place.
3. The new resource is tagged `purpose=restore`, DBA-only (no L3
   applied), with a `ttl`.
4. Run `scripts/validate-restore.sh` against it.
5. Cut over per the request's `cutover` field (manual / dns-swap /
   rename — see [restore-postgres.md](restore-postgres.md) section 5
   for what each means operationally).
6. Record the audit outcome and measured RTO against the tier target.
7. `cleanup-ttl.yml` destroys the restored resource once its `ttl`
   passes — this includes the *original* server if `rename` cutover
   was used and the old resource is now the one pending cleanup.

## Scheduled drills

`restore-drill.yml` runs this exact procedure automatically per the
tier cadence (monthly/quarterly/semi-annual), always in `drill` mode
(auto-destroy regardless of `ttl_hours`, no L3 ever applied). A failed
drill or an RTO exceeding the tier's target should open an issue
automatically — don't wait for a dashboard to be checked.
