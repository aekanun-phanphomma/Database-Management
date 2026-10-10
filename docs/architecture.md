# Architecture

## Layering (ADR 0001)

```mermaid
flowchart TB
  subgraph L0["L0 foundation (per env/region)"]
    NET[network / DNS]
    KMS[KMS / Key Vault]
    BAK[backup vaults]
    OBS[observability]
    RUN[CI runners]
  end

  subgraph L1["L1 server (per database server)"]
    SRV[server / cluster, HA, parameters, private endpoint]
  end

  subgraph L2["L2 databases"]
    DB[logical DBs, schemas, extensions, containers]
  end

  subgraph L3["L3 access"]
    ACC[roles, grants, principals, secrets]
  end

  NET --> SRV
  KMS --> SRV
  BAK --> SRV
  SRV -->|dependency: fqdn, ids| DB
  SRV -->|dependency: fqdn, ids| ACC
  DB -.->|read-only, same request inventory| ACC
```

Each box above is a separate Terragrunt stack with its own state and
its own pipeline identity. See ADR 0001 for why, and section 7 of the
platform spec for the full dependency/state-backend rules.

## Request flow

```mermaid
sequenceDiagram
  participant Team as App team
  participant PR as GitHub PR
  participant CI as CI (schema + policy)
  participant DBA as DBA reviewer
  participant L2 as L2 databases apply
  participant L3 as L3 access apply

  Team->>PR: add requests/<team>/<name>.yaml
  PR->>CI: JSON Schema validation
  CI->>CI: conftest / OPA policy checks
  CI->>PR: plan output (per affected server stack)
  DBA->>PR: review + approve
  PR->>L2: apply (logical DB, schema, extensions)
  PR->>L3: apply (roles, grants, principal bindings)
```

## Why "one stack per server"

Terraform provider blocks cannot be `for_each`'d. The `postgresql`,
`mssql`, and `mysql` providers each authenticate to one server. Since
L2/L3 need those providers, the server is necessarily the
state/provider boundary — see ADR 0001.

## Why many databases can share a server, and when they can't

See ADR 0004. Short version: shared servers share a CMK, maintenance
window, major version, and backup/PITR window; `restricted` data never
shares, and every shared server has an enforced database-count and
connection-budget cap.

## Naming convention

| Thing | Pattern | Example |
|---|---|---|
| AWS server identifier | `<org>-<env>-<engine>-<purpose>` | `acme-prod-pg-shared01` |
| Azure server name | `<engine-abbrev>-<org>-<env>-<region-abbrev>-<purpose>` | `psql-acme-prod-sea-shared01` |
| Logical database | `^[a-z][a-z0-9_]{2,30}$` | `payment` |
| Postgres group role | `<db>_<tier>` | `payment_owner`, `payment_rw` |
| AWS login principal | `<kind>_<db>_<svc>` | `app_payment_api` |
| Azure login principal | Entra object name, bound by object id | `mi-payment-api` |
| Entra group | `grp-<team>-db-eng-<ro\|rw>` | `grp-payment-db-eng-rw` |
| Tags (all resources) | `managed-by, repo, org, env, cloud` minimum | — |

`# TODO(verify)`: finalize the exact AWS/Azure resource-name length
limits per engine (e.g. RDS identifiers cap at 63 chars, Azure
PostgreSQL Flexible server names have their own limit) before this
convention is enforced as a `tflint`/policy rule.
