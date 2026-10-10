# Integration tests

Unit tests for a single module's logic live inside that module, at
`modules/<path>/tests/*.tftest.hcl` (e.g.
[`modules/databases/postgres/tests/guardrails.tftest.hcl`](../modules/databases/postgres/tests/guardrails.tftest.hcl)),
run with `terraform test` from inside the module.

This directory is for the **nightly sandbox integration tests** (spec
section 17.3): apply a real (non-prod) stack into a `sandbox`
environment, run connectivity/permission checks against it, then
destroy. Not yet implemented — see `sandbox-postgres.md` below for
the planned shape.

## Planned: `sandbox-postgres.md`

Checks to run against a live sandbox Postgres server + two databases
(`a`, `b`) before every checklist item is considered "done":

- [ ] `rw` principal can `INSERT`/`UPDATE`/`DELETE` on its own database.
- [ ] `ro` principal can `SELECT` but gets `permission denied` on write.
- [ ] Database `a`'s `rw` principal gets `permission denied` connecting
      to database `b` (proves `REVOKE CONNECT ... FROM PUBLIC` works).
- [ ] An unauthenticated/`PUBLIC` connection attempt is rejected.
- [ ] The migration identity (`SET ROLE <db>_owner`) creates a table,
      and the `rw` role can immediately read/write it without an
      extra grant step (proves `postgresql_default_privileges` works).

This is currently a checklist, not automation — `scripts/` has no
sandbox-apply/teardown script yet. Building that script and a
`sandbox` Terragrunt environment tree under `live/` is the next piece
of this directory's TODO, not something to fake with a placeholder
test file.
