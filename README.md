# db-platform

Database Platform as Code for AWS + Azure (SQL + NoSQL), owned by the
DBA team. Application teams request databases and access **only**
through YAML pull requests under [`requests/`](requests/) — never
through the cloud console.

## What this is

- Terraform + Terragrunt provisioning of everything a database needs:
  network, encryption, the server itself, logical databases/schemas,
  roles and grants, backups, and restores.
- Self-service for app teams via a YAML contract
  (`requests/<team>/<name>.yaml`), validated by JSON Schema and by
  Terraform preconditions, then applied by the DBA-owned pipeline.
- Explicitly **out of scope**: table/index/data changes. Those belong
  to app teams' own migration tool (Flyway/Liquibase/EF). This
  platform only creates the `<db>_owner` role and the migration
  identity those tools use.

## Why it's shaped this way

Read these before changing anything structural:

- [docs/adr/0001-layering.md](docs/adr/0001-layering.md) — why there
  are 4 separate Terraform state layers (L0–L3) per server, and why
  the server is a hard state boundary.
- [docs/adr/0002-versions.md](docs/adr/0002-versions.md) — pinned
  Terraform/provider versions and why (`ephemeral` resources,
  write-only arguments).
- [docs/adr/0003-auth.md](docs/adr/0003-auth.md) — the passwordless-
  first authentication order and when a password is still allowed.
- [docs/adr/0004-shared-servers.md](docs/adr/0004-shared-servers.md)
  — how many databases can share one server, and the guardrails that
  keep one tenant from affecting another.
- [docs/architecture.md](docs/architecture.md) — diagrams and the
  naming convention.

## Requesting a database

1. Copy [`requests/_schema/example-payment.yaml.sample`](requests/_schema/example-payment.yaml.sample)
   to `requests/<your-team>/<name>.yaml`.
2. Fill it in. CI validates it against
   [`requests/_schema/request.schema.json`](requests/_schema/request.schema.json)
   and against capacity/classification policy before a DBA ever looks
   at it.
3. Open a PR. A DBA reviews and approves; CI applies the L2 (database)
   and L3 (access) stacks for the server you named.

If your server choice is rejected for capacity or data-classification
reasons, that's `modules/databases/*/guardrails.tf` doing its job —
see ADR 0004 for why shared servers are capped.

## Requesting a restore

Restores are also YAML, under [`restores/`](restores/), and always
restore to a **new** resource — never in place. See section 13 of the
platform design for restore modes (`full-server`, `single-db`,
`drill`) and `docs/runbooks/` for the operational playbooks.

## Repository layout

See [docs/architecture.md](docs/architecture.md) for the full diagram.
At a glance:

```text
modules/        reusable Terraform modules (foundation, per-engine, databases, access, restore)
live/           Terragrunt stacks, one tree per cloud/env/region/server
requests/       the ONLY folder app teams edit — database requests
restores/       restore requests
policies/       Rego policy-as-code (conftest)
docs/adr/       architecture decision records
docs/runbooks/  restore / break-glass / rotation runbooks
```

## Status

This repository is being built phase by phase (per the platform
design doc, §20). Current phase: **1 — repository scaffold**
(structure, ADRs, tooling config, request schema). No cloud
infrastructure modules are implemented yet.
