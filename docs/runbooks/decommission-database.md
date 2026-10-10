# Runbook: decommissioning a database

The reverse of [onboarding.md](onboarding.md). Removing a database
request is not a plain `terraform destroy` — `prevent_destroy` is on
by design (ADR 0001/0004), and the platform spec's anti-patterns list
explicitly forbids destroying stateful resources without a deliberate
path.

## Procedure

1. **Confirm with the requesting team** that the database is truly no
   longer needed — not just unused this quarter. Check for read
   replicas, reporting jobs, or scheduled exports that might still
   depend on it.
2. **Take a final logical backup** outside the normal PITR/backup
   schedule: `pg_dump -Fd` (or the engine-appropriate export) to
   immutable storage, retained per the team's actual compliance
   requirement — not just the tier's standard retention, since the
   database won't exist anymore to re-derive this from.
3. **Open a PR removing the database from its `requests/<team>/*.yaml`
   file.** This alone does *not* delete anything — the L2/L3 stacks
   will plan a `delete`, which the `deny_destroy` policy
   (`policies/deny_destroy.rego`) blocks unless the PR carries the
   `break-glass` label with two DBA approvals. That friction is
   intentional for a decommission, not a bug to route around.
4. On approval, remove `lifecycle { prevent_destroy = true }` for that
   specific resource in a **follow-up commit** (never remove it
   silently as part of the same change that triggers the delete —
   keep the "I am intentionally allowing this delete" step visible in
   the diff).
5. Apply. The L3 (access) resources for that database go first
   (grants reference the database), then L2 (the database itself).
6. **Do not immediately decommission the server** if other databases
   remain on it — only remove the one entry. If this was the last
   database on a dedicated (non-shared) server, that's a separate L1
   decommission, planned on its own with its own sign-off.
7. File the final backup's location and retention date against the
   decommission ticket.

## What NOT to do

- Don't set `prevent_destroy = false` repo-wide "to make this easier"
  — scope the change to the one resource being removed.
- Don't skip the final backup because "we have PITR anyway" — PITR's
  retention window is shorter than most compliance retention
  requirements and disappears the moment the server/database is gone.
