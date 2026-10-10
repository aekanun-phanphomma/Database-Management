# Runbook: Onboarding a new team / requesting your first database

## 1. Pick a server, or ask for one

Browse `requests/` for existing servers your data classification and
tier are allowed on (ADR 0004 — a server's `allowed_classifications`
and `tier` gate this). If nothing fits — your data is `restricted`,
or every shared server is at its 20-database cap — ask the DBA team
for a new dedicated server (that's a separate, DBA-initiated L1
change, not something `requests/` YAML can create on its own).

## 2. Write the request

Copy `requests/_schema/example-payment.yaml.sample` to
`requests/<your-team>/<name>.yaml`. Required fields are enforced by
`requests/_schema/request.schema.json` — CI will tell you exactly
what's missing or malformed before a human ever looks at it.

Things that trip people up:

- `server` must match an existing server's directory name exactly
  (e.g. `psql-shared01`, not the fully-qualified Azure resource name).
- `access.apps[].principal` is a Managed Identity name on Azure, an
  IAM role name on AWS (spec section 9.1) — not a human username
  either way. Apps authenticate with identity auth, never passwords
  (ADR 0003).
- `access.engineers[].group` must be an existing Entra/IdC group.
  `eng_rw` groups should be PIM-eligible-only, not permanently
  assigned — that's what makes break-glass write access auditable.

## 3. Open the PR

CI runs schema validation, the duplicate-(server,database) check
(`scripts/check-duplicates.sh`), and policy checks. A DBA reviews and
approves. On merge, CI applies the matching server's `20-databases`
and `30-access` stacks only — not the whole platform.

## 4. What you get

- A database owned by `<name>_owner`, with your requested schemas and
  extensions.
- `<name>_rw` / `<name>_ro` roles bound to the app principals you
  listed, `<name>_eng_ro` / `<name>_eng_rw` bound to your Entra
  groups.
- Backups per your `tier` (spec section 13.1) — you don't need to
  configure this yourself.

## 5. What you don't get

Table/index/data changes. This platform creates the `<name>_owner`
role and your migration identity's binding to it; your own migration
tool (Flyway/Liquibase/EF) does everything after that, running `SET
ROLE <name>_owner` before DDL so the default-privilege grants (spec
section 10.6) apply automatically to new objects.
