# Runbook: major engine version upgrade

Covers bumping e.g. Postgres 16 → 17, not a patch/minor update
(`auto_minor_version_upgrade = true` already handles those
automatically across every L1 module in this repo).

## Why this needs its own runbook

A major version upgrade on a **shared server** (ADR 0004) affects
every database and every tenant on it at once — there is no way to
upgrade one database's engine version independently of the others on
the same server. This is exactly the kind of blast radius ADR 0004
warns requesters about up front.

## Procedure

1. **Check every database's extensions and app compatibility** against
   the target version first. `modules/azure/sql/postgres-flexible`'s
   `azure.extensions` server parameter is the union of every
   database's requested extensions (spec section 10.2.7) — confirm
   every one of them is supported on the target version before
   starting, not after.
2. **Take a full backup/snapshot immediately before the change**,
   independent of the normal PITR window, so there's a known-good
   rollback point that isn't affected by the upgrade itself.
3. **Schedule a maintenance window** and notify every team with a
   database on the server — this is a shared-server event, not a
   per-tenant one.
4. Bump `engine_version` (RDS/Aurora) or `pg_version`/`mysql_version`
   (Azure Flexible) in the server's `10-server` stack. For RDS/Aurora,
   confirm the matching parameter group `family` string also needs to
   change (e.g. `postgres16` → `postgres17`) — the parameter group
   resource name is currently **hardcoded** per engine major version
   in `modules/aws/sql/rds-postgres/main.tf` (marked `TODO(verify):
   derive from var.engine_version major instead of hardcoding`), so
   this is a two-line change, not a one-line change, until that TODO
   is resolved.
5. Apply during the maintenance window. AWS RDS/Aurora major upgrades
   are **not reversible** in place — rollback means restoring from the
   pre-upgrade snapshot, not downgrading the engine.
6. Run the full validation checklist from
   [tests/README.md](../../tests/README.md)'s planned sandbox
   integration checks against the upgraded server before declaring it
   done.
7. Record the before/after version and the validation result against
   the change ticket.

## Known gap

This repo does not yet have a Terraform-native way to stage a major
upgrade with automatic rollback — step 5's "not reversible in place"
is a real operational risk this runbook can only manage procedurally
(snapshot-first), not eliminate via Terraform. A blue/green deployment
pattern (new server, replicate, cut over, decommission old) would
remove this risk but is not implemented.
