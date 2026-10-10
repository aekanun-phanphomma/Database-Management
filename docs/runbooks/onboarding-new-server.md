# Runbook: onboarding a new server

For the DBA team provisioning a **new server** (dedicated or
shared-capable) — distinct from [onboarding.md](onboarding.md), which
is for app teams requesting a *database on an existing server*.

## When a new server is needed

- A team's data is `data_classification: restricted` — ADR 0004
  requires a dedicated server; it cannot be placed on any existing
  shared server, however much capacity that server has free.
- Every existing shared server for the target env/engine/classification
  combination is at its `max_databases_per_server` cap (default 20) or
  its connection budget.
- A genuinely new engine/region combination has no server yet.

## Procedure

1. **Pick the engine and tier.** The tier should reflect the *highest*
   tier any database expected to live here will need (ADR 0004) — if
   this will be a shared server, size it for the worst case up front,
   since the server's tier can't easily be downgraded later without a
   disruptive change.
2. **Create the `10-server` Terragrunt stack** under
   `live/<cloud>/<env>/<region>/servers/<server-name>/10-server/`,
   following the pattern in `live/aws/dev/ap-southeast-1/servers/
   pg-shared01/10-server/terragrunt.hcl` or the Azure equivalent.
   Pass naming components (`org_prefix`/`env`/`region_abbr`/`purpose`)
   rather than hand-writing the identifier — see
   `modules/_shared/naming` and spec section 19.
3. **Set `allowed_classifications` deliberately.** This is the actual
   enforcement point for ADR 0004's placement rule — a server with
   `restricted` in its allowed list can only be truly dedicated in
   practice (set `max_databases_per_server = 1` for a server meant to
   be genuinely dedicated, so the guardrail in
   `modules/databases/postgres/guardrails.tf` catches an accidental
   second request).
4. **Create the matching `20-databases` and `30-access` stacks**,
   copying the request-routing pattern (`server_name =
   basename(dirname(get_terragrunt_dir()))`, filtering
   `requests/**/*.yaml` by `spec.server == local.server_name`).
5. **Apply `10-server` first, alone**, and confirm it's healthy
   (connectable, diagnostics flowing to the Log Analytics workspace /
   CloudWatch log group) before any database request can target it.
6. **Tell requesters the server exists** — update the README's list of
   available shared servers (or the equivalent internal reference) so
   `docs/runbooks/onboarding.md`'s step 1 ("pick a server") has
   something current to point at.
7. Confirm backups are actually running (check the AWS Backup plan
   selection / Azure Backup vault) before accepting the first real
   database request — a server with no verified backup path accepting
   production data is the exact failure mode [[0006-restore-strategy]]
   exists to prevent.
