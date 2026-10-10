# Runbook: Restoring a PostgreSQL database

Applies to RDS PostgreSQL, Aurora PostgreSQL, and Azure PostgreSQL
Flexible Server. See spec section 13 and ADR 0004 for why restores
always go to a new resource.

## 1. Open a restore request

Copy `restores/example-2026-10-10-payment.yaml.sample` to
`restores/<name>.yaml`, fill in the ticket, reason, target server,
mode, and restore time. Open a PR. **Prod requires two DBA
approvals.**

## 2. Pick the right mode

| Mode | When | What happens |
|---|---|---|
| `full-server` | server-level corruption, DR drill, region failure | `modules/restore/aws-rds-pitr` or `azure-pg-pitr` restores the whole server to a new resource. **Every database on a shared server comes back**, at the point in time you chose. |
| `single-db` | one tenant's data needs rolling back, server is otherwise fine | Same restore-to-new-resource first, then `scripts/restore-single-db-pg.sh` pulls just that one database out via `pg_dump`/`pg_restore` into a **new** database on the live server. |
| `drill` | scheduled test | Same as `full-server`, but auto-destroyed by `cleanup-ttl.yml` regardless of ttl_hours, and never gets an L3 access stack applied. |

## 3. Apply the restore stack

CI applies the matching `modules/restore/*` module. The resulting
resource is tagged `purpose=restore`, `restore-ticket=<id>`, and
`ttl=<timestamp>`. **No L3 (access) stack is applied to it.** Only
the DBA pipeline identity and break-glass group can reach it.

## 4. Validate

Run `scripts/validate-restore.sh <host> <database>`. This checks
connectivity, flags zero-row tables for manual review, and confirms
the server isn't still in recovery. A human still has to spot-check
the actual data — this script does not replace that.

## 5. Cut over

Per the request's `cutover` field:

- `manual` — DBA manually repoints the app config. Lowest blast
  radius, slowest.
- `dns-swap` — flip the server's private Route53/Azure Private DNS
  record to the restored resource's address. This is why L1 creates a
  stable CNAME per server (spec section 8.1) — cutover becomes a DNS
  change, not an app redeploy.
- `rename` — rename the restored resource to take over the original's
  identifier (full-server mode only; the original must be
  decommissioned first).

## 6. Record the outcome

Every restore must produce an audit record: who, what, when, source,
point in time, result, and measured RTO against the tier's target
(spec section 13.1). File this against the ticket.

## 7. Cleanup

`cleanup-ttl.yml` runs nightly and destroys anything past its `ttl`
tag. Don't rely on remembering to clean up manually — it's
TTL-enforced on purpose.
