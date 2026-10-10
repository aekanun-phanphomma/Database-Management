# Runbook: importing an existing (pre-platform) database

For a database that already exists outside this repo's Terraform
state — created by hand, by an older IaC system, or by a previous
process — and now needs to come under platform management.

## Principle

Use Terraform's `import {}` block, never `terraform import` run
by hand against someone's laptop. An `import {}` block is committed
code, reviewed in a PR like anything else, and reproducible.

## Procedure

1. **Write the `requests/<team>/<name>.yaml`** describing the
   database as if it were new — same schema, same validation. This is
   the target state Terraform will reconcile the real resource into,
   so get the connection_limit/extensions/schemas/access fields right
   first; don't assume the existing resource's current settings are
   what you want going forward.
2. **Identify the resource's real cloud ID** (RDS identifier, Azure
   resource ID, database/role names as they exist today).
3. **Add `import {}` blocks**, scoped to the specific stack
   (`20-databases`/`30-access`) that would normally create this
   resource:
   ```hcl
   import {
     to = postgresql_database.this["payment"]
     id = "payment"
   }
   ```
   One block per resource being adopted — group roles, grants, and
   schemas each need their own `import {}` if they already exist with
   matching names; anything that doesn't exist yet still gets created
   normally by `terraform apply`, the two can coexist in one plan.
4. **Run `terragrunt plan`** and read the diff carefully. Terraform
   will show changes needed to reconcile the real resource's current
   configuration with what the module would otherwise create — expect
   drift here (different `connection_limit`, missing `pgaudit`
   parameters, etc.) and decide case by case whether to adjust the
   request to match reality or accept the plan's corrective changes.
5. **Never import a resource straight into a stack with
   `prevent_destroy = true` and an un-reviewed plan** — read the full
   plan output before applying; an import combined with an
   unreviewed destructive change elsewhere in the same plan is exactly
   the failure mode `prevent_destroy` and the `deny_destroy` policy
   exist to catch, but a human review is still the first line of
   defense.
6. Once applied, remove the `import {}` blocks (they're a one-time
   adoption mechanism, not meant to stay in the codebase — leaving
   them doesn't hurt functionally, but they clutter the stack for
   future readers).
7. Update the request's `ticket` field to reference the adoption
   ticket, so the request's history makes sense to someone reading it
   later.

## What NOT to do

- Don't hand-run `terraform import` against prod state outside a PR —
  it bypasses the whole review process this platform exists to
  enforce.
- Don't skip reading the full diff because "it's just an import" — an
  import still produces a plan, and that plan can contain unrelated
  changes if the request YAML doesn't match the resource's actual
  current state.
