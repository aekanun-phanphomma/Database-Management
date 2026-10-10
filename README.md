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
- [docs/adr/0005-secrets-strategy.md](docs/adr/0005-secrets-strategy.md)
  — the four-tier secrets fallback order and where each tier is
  actually used in this repo today.
- [docs/adr/0006-restore-strategy.md](docs/adr/0006-restore-strategy.md)
  — why restore always targets a new resource, and why single-db mode
  is two different mechanisms depending on engine.
- [docs/adr/0007-role-model.md](docs/adr/0007-role-model.md) — the six
  standard access tiers and how each engine's native model maps to them.
- [docs/architecture.md](docs/architecture.md) — diagrams and the
  naming convention.
- [docs/security-controls.md](docs/security-controls.md) — every
  control from the spec mapped to the file that implements it and the
  policy/test that enforces it, including an honest list of which
  controls aren't policy-enforced yet.

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

Built phase by phase (per the platform design doc, §20):

1. Repository scaffold — structure, ADRs, tooling config, request schema.
2. L0 foundation — network/KMS/Key Vault/backup/observability/state
   backend/CI runners, AWS + Azure.
3. L1 servers for the phase-2 engines — RDS Postgres, Aurora Postgres,
   Azure PostgreSQL Flexible Server.
4. L2 databases + L3 access for Postgres, wired end-to-end for a dev
   server on each cloud.
5. Restore modules, scripts, and runbooks for Postgres PITR.
6. CI/CD workflows (`pr.yml`, `apply.yml`, `drift.yml`, `restore.yml`,
   `restore-drill.yml`, `cleanup-ttl.yml`) and Rego policy-as-code
   (Rego v1, `package dbplatform.*`) with unit tests.
7. Remaining engines from the scope matrix: RDS MySQL/SQL Server,
   DynamoDB, DocumentDB, ElastiCache, Azure SQL/MI, MySQL Flexible,
   Cosmos DB (SQL + Mongo APIs), Azure Cache for Redis — plus their
   restore modules.
8. ADRs 0005–0007, `docs/security-controls.md`, the shared `naming`
   and `tagging` modules, the remaining `docs/runbooks/*` named in the
   spec, and module-local `tests/` per spec section 19's module layout.

Every module is written against the pinned provider versions in
[docs/adr/0002-versions.md](docs/adr/0002-versions.md); where an
argument's exact name or availability couldn't be verified against
live Registry docs, it's marked `# TODO(verify)` in-code rather than
guessed. Before a real `terraform plan`/`apply` against any module,
search the repo for `TODO(verify)` and confirm those arguments first —
particularly around Entra/AAD auth maturity for MySQL Flexible Server
and Azure Cache for Redis, and a handful of restore-specific argument
shapes.

**Known gaps** (see [docs/security-controls.md](docs/security-controls.md)'s
"Known gaps" section for the full, honest list): threat-detection
modules (GuardDuty RDS Protection / Defender for Cloud) and org-level
guardrails (SCPs / Azure Policy) don't exist yet; per-layer IAM/Entra
role *definitions* are referenced by name (`id-<env>-l0..l3`) but not
yet created as Terraform resources; GitHub Actions are pinned to tags,
not SHAs; the `naming`/`tagging` shared modules are wired into the two
flagship Postgres stacks only, not retrofitted across every other
engine's `live/` wiring yet.
