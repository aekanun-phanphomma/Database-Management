# MASTER PROMPT — Terraform Database Platform (AWS + Azure, SQL + NoSQL)

> **How to use this prompt**
> 1. Fill in section **0. Inputs** (anything left blank → the agent must use the stated default and record it in an ADR).
> 2. Give the whole file to the coding agent (Claude Code, etc.) in an **empty git repository**.
> 3. Ask it to work **phase by phase** (section 20). Review and merge each phase before starting the next.

---

## 0. Inputs (fill before running)

| Key | Value | Default if blank |
|---|---|---|
| `org_prefix` | | `acme` |
| Environments | | `dev`, `uat`, `prod` |
| AWS regions (primary / DR) | | `ap-southeast-1` / `ap-southeast-2` |
| Azure regions (primary / DR) | | `southeastasia` / `eastasia` |
| AWS accounts layout | | 1 account per env + 1 `shared-services` + 1 `backup` (isolated) |
| Azure subscriptions layout | | 1 subscription per env + 1 `connectivity` + 1 `management` |
| CI/CD system | | GitHub Actions + self-hosted runners |
| Orchestrator | | Terragrunt (latest 0.x stable) |
| Workforce identity | | Microsoft Entra ID (AWS via IAM Identity Center federated to Entra) |
| Engines in phase 2 | | PostgreSQL (Azure PG Flexible + AWS RDS/Aurora PG) |
| Engines in later phases | | Azure SQL DB/MI, RDS MySQL, RDS SQL Server, Cosmos DB (NoSQL API), DynamoDB, DocumentDB, Redis |
| SIEM | | Microsoft Sentinel / AWS Security Hub |
| ChatOps channel | | Slack/Teams webhook stored as CI secret |

---

## 1. Role

You are a **Principal Platform Engineer and Database Reliability Engineer**. You have deep production experience with Terraform, AWS, Azure, PostgreSQL, SQL Server, Cosmos DB, DynamoDB, security engineering (CIS, NIST 800-53, ISO 27001) and backup/DR design.

You will build a **production-grade, best-practice "Database Platform as Code" repository**. The DBA team owns the repository. Application and engineering teams request databases and access through **YAML pull requests only**.

You write code that is correct, minimal, idempotent, testable, and secure by default. **You never invent resource arguments.** For every resource you use, check the argument names against the Terraform Registry docs for the **pinned provider version**. If you cannot verify an argument, mark it `# TODO(verify): <what to check>` and list it in the phase report. Do not guess silently.

---

## 2. Goals

1. Provision and manage the full lifecycle, entirely through Terraform:
   - Supporting infra: network, DNS, keys, identities, monitoring, backup vaults, CI runners, state backends.
   - Database servers/accounts.
   - Logical databases, schemas, and containers/tables.
   - Users, roles, and permissions for **applications** and **engineers**.
   - Encryption at rest and in transit, and secrets.
   - Backup, **restore**, DR, and restore drills.
2. Support **many databases on one server** safely: isolation, capacity guardrails, blast-radius control.
3. Make **restore** a first-class, automated, auditable, regularly tested workflow, not a wiki page.
4. Be self-service through YAML, with policy-as-code guardrails and DBA approval.

### Out of scope (explicit boundary)

- Table, index, and data changes. These belong to app teams using Flyway, Liquibase, or EF migrations.
- The platform only provides the `<db>_owner` role and the migration identity those tools use.

---

## 3. Non-negotiable principles

1. **Git is the source of truth.** No ClickOps. Any manual change is drift and is reported nightly.
2. **Layered stacks with separate state** (section 7). Never put a server and its database-level provider in the same state.
3. **One stack per database server.** Loop over databases *inside* that stack. Terraform cannot `for_each` provider configurations, so the server boundary is also the provider boundary.
4. **Passwordless first.** Use Entra ID / Managed Identity on Azure and IAM DB auth on AWS. Use a password only when the engine or client cannot support identity auth. In that case Terraform **must never store it in state**: use ephemeral resources and write-only arguments, or let a rotation function own the password.
5. **Encryption by default:**
   - CMK at rest everywhere.
   - TLS 1.2+ enforced.
   - No public endpoints.
   - Private DNS only.
6. **Least privilege everywhere:**
   - Grant permissions to NOLOGIN group roles, never to login users.
   - Pipeline identities are split per layer and per environment.
7. **Restore never overwrites in place.** Always restore to a *new* resource, validate, then cut over explicitly.
8. **Immutability and deletion safety:**
   - `prevent_destroy` on stateful resources in prod.
   - Policy blocks plan-level deletes unless break-glass approval is given.
   - Backups are copied to an isolated account/subscription with immutability (vault lock).
9. **Everything is tagged** and every name follows the naming convention (section 19).
10. **Supply-chain hygiene:**
    - Pin Terraform, providers, modules, and GitHub Actions (by SHA).
    - Commit `.terraform.lock.hcl` with hashes for `linux_amd64`, `darwin_arm64`, and `windows_amd64`.

---

## 4. Tech stack and version pins

Adjust to the latest stable versions at implementation time and record them in `docs/adr/0002-versions.md`.

```hcl
terraform {
  required_version = ">= 1.11.0, < 2.0.0"   # needs ephemeral resources + write-only arguments
  required_providers {
    aws        = { source = "hashicorp/aws",        version = "~> 6.0" }
    azurerm    = { source = "hashicorp/azurerm",    version = "~> 4.0" }
    azuread    = { source = "hashicorp/azuread",    version = "~> 3.0" }
    random     = { source = "hashicorp/random",     version = "~> 3.7" }
    postgresql = { source = "cyrilgdn/postgresql",  version = "~> 1.25" }
    mssql      = { source = "PGSSoft/mssql",        version = "~> 0.6" }
    mysql      = { source = "petoju/mysql",         version = "~> 3.0" }
  }
}
```

Tooling:
- `tflint` with the aws and azurerm rulesets
- `checkov` or `trivy config`
- `conftest` (OPA/Rego)
- `terraform test`
- `infracost`
- `pre-commit`
- `terraform-docs`

---

## 5. Scope matrix (what each cloud × category must provide)

| | **SQL** | **NoSQL** |
|---|---|---|
| **AWS** | RDS PostgreSQL, Aurora PostgreSQL, RDS MySQL, RDS SQL Server | DynamoDB, DocumentDB, ElastiCache (Redis/Valkey) |
| **Azure** | PostgreSQL Flexible Server, Azure SQL Database (+ Elastic Pool), SQL Managed Instance, MySQL Flexible | Cosmos DB (NoSQL API, MongoDB vCore/RU), Azure Cache for Redis |

Every engine module must implement the same **capability contract**:

| Capability | Required |
|---|---|
| Private networking only + private DNS | ✅ |
| CMK at rest + key rotation | ✅ |
| TLS enforced (min 1.2) | ✅ |
| Identity-based admin (Entra group / IAM) | ✅ |
| Identity-based app auth | ✅ (or documented exception) |
| Standard role model (section 11) | ✅ |
| Audit logs → central log workspace / SIEM | ✅ |
| Threat detection (Defender / GuardDuty RDS Protection) | ✅ |
| Backups: retention by tier, cross-region + cross-account/sub copy | ✅ |
| Restore module + runbook + drill | ✅ |
| Metrics alerts (section 15) | ✅ |
| Deletion protection | ✅ |
| `terraform test` coverage | ✅ |

---

## 6. Required repository layout

```
db-platform/
├── README.md
├── docs/
│   ├── adr/                         # 0001-layering.md, 0002-versions.md, 0003-auth.md, ...
│   ├── runbooks/                    # restore-*.md, break-glass.md, rotate-*.md, onboarding.md
│   └── architecture.md              # diagrams (mermaid)
├── modules/
│   ├── foundation/
│   │   ├── aws-network-db/          # DB subnets, SGs, endpoints, Route53 private zones
│   │   ├── aws-kms/                 # per-purpose CMKs, key policies, multi-region replicas
│   │   ├── aws-backup/              # AWS Backup vault (+ lock), plans, cross-account copy
│   │   ├── aws-observability/       # log groups, SNS, event subscriptions, dashboards
│   │   ├── azure-network-db/        # delegated subnets, NSGs, private DNS zones + links
│   │   ├── azure-keyvault/          # KV (RBAC, purge protection, PE), keys with rotation policy
│   │   ├── azure-backup/            # Backup vault (immutable), policies
│   │   ├── azure-observability/     # Log Analytics, action groups, alert baselines
│   │   ├── ci-runner-aws/           # runner infra inside VPC
│   │   ├── ci-runner-azure/         # runner infra inside VNet
│   │   └── state-backend/           # S3 / Storage Account for remote state
│   ├── aws/
│   │   ├── sql/{rds-postgres,aurora-postgres,rds-mysql,rds-sqlserver}/
│   │   └── nosql/{dynamodb-table,documentdb,elasticache}/
│   ├── azure/
│   │   ├── sql/{postgres-flexible,mssql-server,mssql-mi,mysql-flexible}/
│   │   └── nosql/{cosmos-nosql,cosmos-mongo,redis}/
│   ├── databases/                   # L2: logical DBs/schemas/containers (one per engine family)
│   │   ├── postgres/  mssql/  mysql/  cosmos-nosql/  dynamodb/
│   ├── access/                      # L3: role model per engine family
│   │   ├── postgres/  mssql/  mysql/  cosmos-nosql/  dynamodb/
│   └── restore/                     # restore stacks per engine
│       ├── aws-rds-pitr/  azure-pg-pitr/  azure-sql-db-pitr/  cosmos-pitr/  dynamodb-pitr/
├── live/
│   ├── root.hcl                     # Terragrunt: remote_state, provider generation, common inputs
│   ├── aws/<env>/<region>/
│   │   ├── 00-foundation/{network,kms,backup,observability,runner}/
│   │   └── servers/<server-name>/{10-server,20-databases,30-access}/
│   └── azure/<env>/<region>/
│       ├── 00-foundation/...
│       └── servers/<server-name>/{10-server,20-databases,30-access}/
├── requests/                        # ← the ONLY folder app teams edit
│   ├── _schema/request.schema.json  # JSON Schema; validated in CI
│   └── <team>/<request-name>.yaml
├── restores/                        # restore requests (YAML) → restore pipeline
├── policies/                        # Rego + tests
├── scripts/                         # detect-changed-stacks.sh, restore-single-db-pg.sh, validate-restore.sh, ...
├── tests/                           # integration test configs
├── .github/workflows/               # pr.yml, apply.yml, drift.yml, restore.yml, restore-drill.yml, cleanup-ttl.yml
├── .github/CODEOWNERS
├── .pre-commit-config.yaml
└── .tflint.hcl
```

---

## 7. Layers, state and dependencies

| Layer | Path | Contents | Providers | Pipeline identity |
|---|---|---|---|---|
| **L0 foundation** | `00-foundation/*` | network, DNS, KMS/KV, backup vaults, observability, runners | aws / azurerm | `id-<env>-l0` (broad infra rights) |
| **L1 server** | `servers/<s>/10-server` | server/account/cluster, parameters, HA, backup config, private endpoint, diagnostics, Entra/IAM admin | aws / azurerm | `id-<env>-l1` |
| **L2 databases** | `servers/<s>/20-databases` | logical DBs, schemas, extensions, containers, tables (NoSQL) | engine provider + aws/azurerm | `id-<env>-l2` (DB admin, no infra delete) |
| **L3 access** | `servers/<s>/30-access` | group roles, principals, grants, default privileges, Cosmos RBAC, IAM policies, secrets | engine provider + aws/azurerm | `id-<env>-l3` |

Rules:
- Pass L1 outputs to L2/L3 through Terragrunt `dependency` blocks, with `mock_outputs` allowed **only** for `validate` and `plan` on new stacks.
- Remote state:
  - **AWS:** S3 with SSE-KMS, versioning, Object Lock (governance mode), `use_lockfile = true`, bucket policy deny non-TLS.
  - **Azure:** Storage Account with CMK, private endpoint, `shared_access_key_enabled = false`, `use_azuread_auth = true`.
  - The **state of L3 is sensitive.** Only `id-<env>-l3` and the DBA break-glass group can read it.
- The **pipeline identity of L2/L3 must not have rights to delete the server**, and L1 must not have data-plane DB rights.

### Example `live/root.hcl` (Terragrunt)

```hcl
locals {
  path_parts = split("/", path_relative_to_include())
  cloud      = local.path_parts[0]
  env        = local.path_parts[1]
  region     = local.path_parts[2]
  common_tags = {
    managed-by = "terraform"
    repo       = "db-platform"
    env        = local.env
  }
}

remote_state {
  backend = local.cloud == "aws" ? "s3" : "azurerm"
  generate = { path = "backend.tf", if_exists = "overwrite_terragrunt" }
  config = local.cloud == "aws" ? {
    bucket       = "${get_env("ORG_PREFIX")}-${local.env}-tfstate"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    encrypt      = true
    kms_key_id   = get_env("TF_STATE_KMS_KEY_ARN")
    use_lockfile = true
  } : {
    resource_group_name  = "rg-${local.env}-tfstate"
    storage_account_name = "st${get_env("ORG_PREFIX")}${local.env}tfstate"
    container_name       = "tfstate"
    key                  = "${path_relative_to_include()}/terraform.tfstate"
    use_azuread_auth     = true
  }
}
```

---

## 8. Supporting infrastructure (L0)

Build these **before** any database. Each item lists the minimum best-practice settings.

### 8.1 AWS

| Component | Requirements |
|---|---|
| **DB subnets** | Private subnets with no IGW route, across ≥ 3 AZs, and a `aws_db_subnet_group` per env. Size subnets to allow **restore instances** to coexist with prod. |
| **Security groups** | One SG per server. Ingress only from app SGs and the runner SG on the engine port. **No `0.0.0.0/0`.** Egress restricted. |
| **VPC endpoints** | Interface endpoints for `secretsmanager`, `kms`, `logs`, `sts`, `ssm`, `ssmmessages`, `rds` (for runner), and gateway endpoints for `s3` and `dynamodb`. |
| **DNS** | Route53 private hosted zone `db.<env>.internal` with a stable **CNAME per server** (`payment-pg.db.prod.internal → <rds endpoint>`), so a restore cutover is a DNS change, not an app redeploy. |
| **KMS** | Separate CMKs per purpose: `rds`, `dynamodb`, `secrets`, `backup`, `logs`, `tfstate`. Turn on `enable_key_rotation = true`. Use **multi-region keys** where cross-region copy is needed. Key policy separates *key administrators* from *key users*. Deny `kms:ScheduleKeyDeletion` except for break-glass. |
| **Backup** | AWS Backup vault per env, plus a **vault in the isolated `backup` account with Vault Lock (compliance mode)**. Backup plans by tier. Cross-region and cross-account copy rules. |
| **Observability** | CloudWatch log groups (KMS-encrypted, retention by policy), SNS topics (KMS-encrypted), `aws_db_event_subscription`, and a dashboard per server. |
| **Threat detection** | GuardDuty with RDS Protection, Security Hub (CIS + AWS FSBP), CloudTrail org trail including data events where needed. |
| **Engineer access path** | No VPN to the DB subnet. Use **SSM Session Manager port forwarding** through a hardened bastion (no SSH key, no public IP) plus IAM DB auth tokens. Access is granted through IAM Identity Center permission sets. |
| **CI runner** | Ephemeral self-hosted runners (e.g., ECS Fargate / EC2 ASG with actions-runner-controller on EKS) inside the VPC. Use an OIDC trust to IAM roles `id-<env>-l0..l3`. No static AWS keys anywhere. |
| **Org guardrails** | SCPs that deny `rds:*` with `PubliclyAccessible=true`, deny unencrypted create, deny deletion of backup vaults, and restrict regions. |

### 8.2 Azure

| Component | Requirements |
|---|---|
| **Network** | Hub-spoke. DB spoke VNet with **delegated subnets** (`Microsoft.DBforPostgreSQL/flexibleServers`, `Microsoft.DBforMySQL/flexibleServers`, `Microsoft.Sql/managedInstances`) and a private-endpoint subnet. Size delegated subnets for prod plus restore servers. NSGs allow only app subnets and runner subnets. |
| **Private DNS zones** | `privatelink.postgres.database.azure.com`, `privatelink.database.windows.net`, `privatelink.documents.azure.com`, `privatelink.mongo.cosmos.azure.com`, `privatelink.redis.cache.windows.net`, `privatelink.vaultcore.azure.net`, `privatelink.blob.core.windows.net`. Link each zone to the hub and the DB spokes. Zones live centrally in the connectivity subscription. |
| **Key Vault** | One KV per env per region for DB CMKs. `rbac_authorization_enabled = true` (verify the attribute name for the azurerm version), `purge_protection_enabled = true`, `soft_delete_retention_days = 90`, `public_network_access_enabled = false` + PE. Keys: RSA 3072/4096 with a `rotation_policy` (auto-rotate yearly, notify 30 days before expiry). |
| **Identities** | User-assigned identities per server for CMK access (`Key Vault Crypto Service Encryption User` on the key scope only). App workloads use their own UAMI / workload identity. |
| **Entra groups** | `grp-dba-admins`, `grp-<team>-db-eng-ro`, `grp-<team>-db-eng-rw` (**PIM for Groups**: eligible only, max 4h, approval required). |
| **Backup** | Azure Backup vault (immutable, soft delete) for long-term retention where supported (PG Flexible LTR), plus native PITR. Cross-region via geo-redundant backup. |
| **Observability** | Central Log Analytics workspace, diagnostic settings on every DB resource (all audit/security categories), action groups, metric alert baselines. |
| **Threat detection** | Defender for Cloud plans: open-source relational DBs, Azure SQL, Cosmos DB. |
| **Engineer access path** | Azure Bastion / P2S VPN into the hub, with Entra auth to the DB and PIM elevation for rw. |
| **CI runner** | Ephemeral self-hosted runners (Container Apps jobs or AKS ARC) in a runner subnet. Federated credentials (GitHub OIDC) on app registrations `id-<env>-l0..l3`. |
| **Azure Policy** | Deny public network access for DB services, require CMK, require diagnostic settings (DeployIfNotExists), require TLS 1.2, allowed locations, required tags. |

---

## 9. Self-service data contract (YAML)

### 9.1 Request file

```yaml
# requests/payment-team/payment.yaml
apiVersion: dbplatform/v1
kind: DatabaseRequest
metadata:
  name: payment
  team: payment-team
  cost_center: CC-1234
  ticket: CHG-2026-0412
spec:
  cloud: azure                      # aws | azure
  env: prod
  engine: postgres-flexible         # see engines list in schema
  server: psql-acme-prod-sea-shared01
  data_classification: confidential # public | internal | confidential | restricted
  tier: tier1                       # drives backup/RPO/RTO (section 13.1)
  databases:
    - name: payment
      connection_limit: 80
      extensions: [pgcrypto, uuid-ossp]
      schemas: [app, audit]
  access:
    apps:
      - principal: mi-payment-api            # UAMI name (Azure) / IAM role (AWS)
        object_id: 00000000-0000-0000-0000-000000000000  # Azure only
        role: rw
      - principal: mi-payment-report
        object_id: 00000000-0000-0000-0000-000000000000
        role: ro
    migration:
      principal: mi-payment-migrator
      object_id: 00000000-0000-0000-0000-000000000000
    engineers:
      - group: grp-payment-db-eng-ro
        object_id: 00000000-0000-0000-0000-000000000000
        role: eng_ro
      - group: grp-payment-db-eng-rw         # PIM-eligible group only
        object_id: 00000000-0000-0000-0000-000000000000
        role: eng_rw
```

### 9.2 Validation (two layers)

1. **JSON Schema** (`requests/_schema/request.schema.json`) validated in CI with `check-jsonschema`. It checks enums, name regex `^[a-z][a-z0-9_]{2,30}$`, required fields, and allowed role names.
2. **Terraform `validation` / `precondition`** inside the modules, for anything that needs context such as server capacity or classification rules (section 10.3).

### 9.3 Routing requests to server stacks

Each `live/.../servers/<server>/20-databases/terragrunt.hcl` loads **all** request files and filters on `spec.server == <this server>`.

```hcl
# live/azure/prod/southeastasia/servers/psql-acme-prod-sea-shared01/20-databases/terragrunt.hcl
include "root" { path = find_in_parent_folders("root.hcl") }

locals {
  server_name   = basename(dirname(get_terragrunt_dir()))
  request_files = fileset("${get_repo_root()}/requests", "**/*.yaml")
  requests = [
    for f in local.request_files : yamldecode(file("${get_repo_root()}/requests/${f}"))
    if !startswith(f, "_") && yamldecode(file("${get_repo_root()}/requests/${f}")).spec.server == local.server_name
  ]
  # Flatten: one map entry per logical database, keyed by db name (stable key!)
  databases = merge([
    for r in local.requests : {
      for d in r.spec.databases : d.name => merge(d, {
        team                = r.metadata.team
        data_classification = r.spec.data_classification
        tier                = r.spec.tier
        access              = r.spec.access
      })
    }
  ]...)
}

dependency "server" {
  config_path = "../10-server"
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = { fqdn = "mock.postgres.database.azure.com", max_connections = 1000, allowed_classifications = ["internal"] }
}

terraform { source = "${get_repo_root()}/modules/databases/postgres" }

inputs = {
  server_fqdn                     = dependency.server.outputs.fqdn
  server_max_connections          = dependency.server.outputs.max_connections
  server_allowed_classifications  = dependency.server.outputs.allowed_classifications
  databases                       = local.databases
}
```

> A duplicate DB name across request files makes `merge()` silently override. **Add a CI check** (`scripts/check-duplicates.sh`) that fails on duplicate `(server, database)` pairs and on duplicate principals.

---

## 10. Many databases on one server — design rules

### 10.1 Placement rules (which server a DB may live on)

- A server has an `allowed_classifications` list and a `tier`. `restricted` data gets a **dedicated server** because:
  - PG/MySQL CMK, backup, and restore are **server-level**.
  - A noisy neighbor or a restore event would otherwise affect other teams.
- On a shared server, every DB shares the CMK, maintenance window, major version, backup, PITR, and failover. Document this in `docs/adr/0004-shared-servers.md` and show it to requesters in the README.
- Set a maximum number of DBs per shared server (default **20**) and a connection budget.

### 10.2 Isolation inside one server

**PostgreSQL** (roles are **cluster-wide**, so names must be prefixed per database):

1. `REVOKE CONNECT ON DATABASE <db> FROM PUBLIC;` Only that DB's roles may connect.
2. `REVOKE ALL ON SCHEMA public FROM PUBLIC;` Apps use named schemas.
3. Group roles per DB: `<db>_owner`, `<db>_rw`, `<db>_ro`, `<db>_eng_ro`, `<db>_eng_rw`, all **NOLOGIN**.
4. Login principals are named `<kind>_<db>_<svc>` on AWS (e.g., `app_payment_api`). On Azure they use the Entra name and are bound by **object id**.
5. Per-role guardrails: `connection_limit`, `statement_timeout`, `idle_in_transaction_session_timeout`.
6. `ALTER DEFAULT PRIVILEGES FOR ROLE <db>_owner ...` so that objects created by migrations, which must `SET ROLE <db>_owner`, are automatically granted.
7. Extensions are allowlisted per server. On Azure the server parameter `azure.extensions` must be the **union** of the extensions requested by all DBs on that server. L1 reads this from the requests.

**SQL Server / Azure SQL:** users and roles are **per database** (contained users), so there is no cross-DB naming collision. Use an Elastic Pool with per-DB `min/max capacity` to contain noisy neighbors.

**Cosmos DB:** isolation through RBAC **scope** (`/dbs/<db>` or `/dbs/<db>/colls/<c>`). Prefer **dedicated container throughput** for tier1 workloads. Shared database throughput only for small workloads.

**DynamoDB:** one table per workload and an IAM policy per table, optionally with `dynamodb:LeadingKeys` for tenant isolation.

### 10.3 Capacity and policy guardrails as code

```hcl
# modules/databases/postgres/guardrails.tf
resource "terraform_data" "guardrails" {
  lifecycle {
    precondition {
      condition = (
        sum(concat([0], [for d in var.databases : d.connection_limit]))
        <= var.server_max_connections - var.reserved_connections
      )
      error_message = "Sum of database connection_limit exceeds server budget (max_connections - reserved)."
    }
    precondition {
      condition     = length(var.databases) <= var.max_databases_per_server
      error_message = "Too many databases on this server; request a new server."
    }
    precondition {
      condition = alltrue([
        for d in var.databases : contains(var.server_allowed_classifications, d.data_classification)
      ])
      error_message = "A database's data_classification is not allowed on this server."
    }
  }
}
```

### 10.4 Blast-radius rules for loops

- **Always use `for_each` with stable string keys (DB name, principal name). Never use `count`** for databases, roles, or grants.
- Model renames with `moved {}` blocks, never with delete and recreate.
- Policy (section 16.3) **blocks any `delete` or `replace`** of `postgresql_database`, `azurerm_*_database`, `azurerm_cosmosdb_sql_database/container`, `aws_dynamodb_table`, servers, and keys, unless a break-glass label is present and two DBA approvals are given.
- Keep `-parallelism` modest (e.g., 4) on L2/L3 for servers that serialize control-plane changes (Azure server parameters). Document the retry behavior.

### 10.5 Example — L2 PostgreSQL databases module

```hcl
# modules/databases/postgres/variables.tf
variable "databases" {
  description = "Map of logical databases keyed by name."
  type = map(object({
    team                = string
    data_classification = string
    tier                = string
    connection_limit    = optional(number, 50)
    extensions          = optional(list(string), [])
    schemas             = optional(list(string), ["app"])
    access              = any
  }))

  validation {
    condition     = alltrue([for k, _ in var.databases : can(regex("^[a-z][a-z0-9_]{2,30}$", k))])
    error_message = "Database names must match ^[a-z][a-z0-9_]{2,30}$."
  }
}
```

```hcl
# modules/databases/postgres/main.tf
locals {
  tiers = ["owner", "rw", "ro", "eng_ro", "eng_rw"]

  # "<db>_<tier>" => { database, tier }
  group_roles = merge([
    for db, _ in var.databases : {
      for t in local.tiers : "${db}_${t}" => { database = db, tier = t }
    }
  ]...)

  # "<db>.<schema>" => { database, schema }
  schemas = merge([
    for db, cfg in var.databases : {
      for s in cfg.schemas : "${db}.${s}" => { database = db, schema = s }
    }
  ]...)

  # "<db>.<ext>" => { database, extension }
  extensions = merge([
    for db, cfg in var.databases : {
      for e in cfg.extensions : "${db}.${e}" => { database = db, extension = e }
    }
  ]...)
}

resource "postgresql_role" "group" {
  for_each = local.group_roles
  name     = each.key
  login    = false
  inherit  = true
}

resource "postgresql_database" "this" {
  for_each          = var.databases
  name              = each.key
  owner             = postgresql_role.group["${each.key}_owner"].name
  connection_limit  = each.value.connection_limit
  allow_connections = true

  lifecycle {
    prevent_destroy = true
  }
}

# Lock the door: nobody connects unless explicitly granted.
resource "postgresql_grant" "revoke_public_connect" {
  for_each    = var.databases
  database    = postgresql_database.this[each.key].name
  role        = "public"
  object_type = "database"
  privileges  = []
}

resource "postgresql_grant" "revoke_public_schema" {
  for_each    = var.databases
  database    = postgresql_database.this[each.key].name
  role        = "public"
  schema      = "public"
  object_type = "schema"
  privileges  = []
}

resource "postgresql_grant" "connect" {
  for_each    = local.group_roles
  database    = postgresql_database.this[each.value.database].name
  role        = postgresql_role.group[each.key].name
  object_type = "database"
  privileges  = each.value.tier == "owner" ? ["CONNECT", "CREATE", "TEMPORARY"] : ["CONNECT"]
}

resource "postgresql_schema" "this" {
  for_each     = local.schemas
  name         = each.value.schema
  database     = postgresql_database.this[each.value.database].name
  owner        = postgresql_role.group["${each.value.database}_owner"].name
  drop_cascade = false
}

resource "postgresql_extension" "this" {
  for_each = local.extensions
  name     = each.value.extension
  database = postgresql_database.this[each.value.database].name
}
```

### 10.6 Example — schema grants and default privileges (L3 or L2, choose one and document it)

```hcl
locals {
  table_privs = {
    rw     = ["SELECT", "INSERT", "UPDATE", "DELETE"]
    ro     = ["SELECT"]
    eng_ro = ["SELECT"]
    eng_rw = ["SELECT", "INSERT", "UPDATE", "DELETE"]
  }
  sequence_privs = {
    rw     = ["USAGE", "SELECT", "UPDATE"]
    ro     = ["SELECT"]
    eng_ro = ["SELECT"]
    eng_rw = ["USAGE", "SELECT", "UPDATE"]
  }

  # "<db>.<schema>:<tier>" => {...}
  schema_tier = merge([
    for k, s in local.schemas : {
      for t, _ in local.table_privs : "${k}:${t}" => merge(s, { tier = t, role = "${s.database}_${t}" })
    }
  ]...)
}

resource "postgresql_grant" "schema_usage" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  role        = each.value.role
  object_type = "schema"
  privileges  = ["USAGE"]
}

resource "postgresql_grant" "tables" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  role        = each.value.role
  object_type = "table"
  objects     = []                          # all existing tables
  privileges  = local.table_privs[each.value.tier]
}

resource "postgresql_default_privileges" "tables" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  owner       = "${each.value.database}_owner"   # migrations MUST `SET ROLE <db>_owner`
  role        = each.value.role
  object_type = "table"
  privileges  = local.table_privs[each.value.tier]
}

resource "postgresql_default_privileges" "sequences" {
  for_each    = local.schema_tier
  database    = each.value.database
  schema      = each.value.schema
  owner       = "${each.value.database}_owner"
  role        = each.value.role
  object_type = "sequence"
  privileges  = local.sequence_privs[each.value.tier]
}
```

---

## 11. Access model (users and roles) per engine

### 11.1 Standard tiers (identical semantics on every engine)

| Tier | Purpose | Who | Auth | Notes |
|---|---|---|---|---|
| `owner` | Owns schemas, runs DDL | migration identity only | MI / IAM | Apps never run as owner. |
| `rw` | DML | application | MI / IAM | |
| `ro` | read | reporting, read replicas | MI / IAM | |
| `eng_ro` | read for engineers | Entra / IdC group | SSO + token | Consider PII masking views. |
| `eng_rw` | break-glass write | PIM-eligible group | SSO + PIM | Time-bound, ticket required, alert on use. |
| `dba_admin` | server admin | `grp-dba-admins` | SSO | Server-level Entra admin / IAM. |

### 11.2 Azure PostgreSQL Flexible — Entra principals

- The server has `password_auth_enabled = false`.
- Entra admins are the **DBA group** and the **L3 pipeline service principal**.
- Principals are created idempotently by **object id**, then bound to group roles:

```hcl
# modules/access/postgres/azure_principals.tf
locals {
  principals = merge([
    for db, cfg in var.databases : merge(
      { for a in try(cfg.access.apps, []) :
          "${db}:${a.principal}" => { database = db, name = a.principal, oid = a.object_id, type = "service", grant = "${db}_${a.role}" } },
      { "${db}:${cfg.access.migration.principal}" = {
          database = db, name = cfg.access.migration.principal, oid = cfg.access.migration.object_id, type = "service", grant = "${db}_owner" } },
      { for e in try(cfg.access.engineers, []) :
          "${db}:${e.group}" => { database = db, name = e.group, oid = e.object_id, type = "group", grant = "${db}_${e.role}" } }
    )
  ]...)
  unique_principals = { for k, p in local.principals : p.name => p... }
}

# Create Entra-backed login roles (idempotent). Runs on the runner, which is inside the VNet.
resource "terraform_data" "entra_principal" {
  for_each = { for name, list in local.unique_principals : name => list[0] }
  input    = each.value

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    environment = { PGHOST = var.server_fqdn, PGDATABASE = "postgres", PGSSLMODE = "verify-full" }
    command = <<-EOT
      psql -v ON_ERROR_STOP=1 -tAc "
        SELECT pgaadauth_create_principal_with_oid('${each.value.name}', '${each.value.oid}', '${each.value.type}', false, false)
        WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${each.value.name}');"
    EOT
  }
  # Destroy path: handled by runbook (REASSIGN OWNED / DROP OWNED / DROP ROLE). Never auto-drop in prod.
}

resource "postgresql_grant_role" "bind" {
  for_each   = local.principals
  role       = each.value.name
  grant_role = each.value.grant
  depends_on = [terraform_data.entra_principal]
}
```

> If the pinned `cyrilgdn/postgresql` version offers a native resource for arbitrary SQL, prefer it over `local-exec` and document the choice in an ADR. Validate every identifier from YAML against a strict regex before interpolating it into SQL.

### 11.3 AWS RDS / Aurora PostgreSQL — IAM DB auth

- Bootstrap once per server, in the `30-access` stack. Read the RDS-managed master secret **ephemerally** and use it only to create the `tf_admin` IAM-enabled role. After that, use `tf_admin` with IAM auth.

```hcl
ephemeral "aws_secretsmanager_secret_version" "master" {
  secret_id = var.master_user_secret_arn          # from aws_db_instance.master_user_secret[0].secret_arn
}

provider "postgresql" {
  alias     = "bootstrap"
  scheme    = "awspostgres"
  host      = var.server_endpoint
  port      = 5432
  database  = "postgres"
  username  = jsondecode(ephemeral.aws_secretsmanager_secret_version.master.secret_string)["username"]
  password  = jsondecode(ephemeral.aws_secretsmanager_secret_version.master.secret_string)["password"]
  sslmode   = "verify-full"
  superuser = false
}

provider "postgresql" {
  scheme             = "awspostgres"
  host               = var.server_endpoint
  port               = 5432
  database           = "postgres"
  username           = "tf_admin"
  aws_rds_iam_auth   = true
  aws_rds_iam_region = var.region
  sslmode            = "verify-full"
  superuser          = false
}
```

- App login roles: `postgresql_role { login = true, roles = ["rds_iam", "<db>_rw"], connection_limit, statement_timeout }`.
- IAM policy for the app's IAM role (IRSA / EKS Pod Identity / ECS task role):

```hcl
data "aws_iam_policy_document" "db_connect" {
  statement {
    actions   = ["rds-db:connect"]
    resources = ["arn:aws:rds-db:${var.region}:${var.account_id}:dbuser:${var.dbi_resource_id}/app_payment_api"]
  }
}
```

- Engineers: an IAM Identity Center permission set with `rds-db:connect` on `eng_ro_<db>` users only, plus SSM port forwarding.

### 11.4 Azure SQL / SQL MI (`PGSSoft/mssql`)

- `azurerm_mssql_server` with `azuread_administrator { azuread_authentication_only = true, login_username = "grp-dba-admins", object_id = ... }` and `minimum_tls_version = "1.2"`.
- Per DB: custom roles `role_rw`, `role_ro`, `role_eng_ro`, `role_owner`. Avoid granting `db_owner` to apps.

```hcl
provider "mssql" {
  hostname   = var.server_fqdn
  port       = 1433
  azure_auth = {}               # uses the pipeline's federated Entra identity
}

data "mssql_database" "this" {
  for_each = var.databases
  name     = each.key
}

resource "mssql_database_role" "rw" {
  for_each    = var.databases
  name        = "role_rw"
  database_id = data.mssql_database.this[each.key].id
}

resource "mssql_database_permission" "rw" {
  for_each     = { for p in setproduct(keys(var.databases), ["SELECT", "INSERT", "UPDATE", "DELETE", "EXECUTE"]) : "${p[0]}:${p[1]}" => { db = p[0], perm = p[1] } }
  principal_id = mssql_database_role.rw[each.value.db].id
  permission   = each.value.perm
}

resource "mssql_azuread_service_principal" "app" {
  for_each    = local.mssql_app_bindings          # "<db>:<principal>" => { db, name, client_id, role }
  name        = each.value.name
  client_id   = each.value.client_id
  database_id = data.mssql_database.this[each.value.db].id
}

resource "mssql_database_role_member" "app" {
  for_each  = local.mssql_app_bindings
  role_id   = mssql_database_role.rw[each.value.db].id   # pick by each.value.role in real code
  member_id = mssql_azuread_service_principal.app[each.key].id
}
```

### 11.5 Cosmos DB — data-plane RBAC

```hcl
locals {
  cosmos_builtin = {
    ro = "00000000-0000-0000-0000-000000000001"   # Cosmos DB Built-in Data Reader
    rw = "00000000-0000-0000-0000-000000000002"   # Cosmos DB Built-in Data Contributor
  }
}

resource "azurerm_cosmosdb_sql_role_assignment" "this" {
  for_each            = local.cosmos_bindings      # "<db>:<principal>" => { database, principal_id, role }
  resource_group_name = var.resource_group_name
  account_name        = var.account_name
  role_definition_id  = "${var.account_id}/sqlRoleDefinitions/${local.cosmos_builtin[each.value.role]}"
  principal_id        = each.value.principal_id
  scope               = "${var.account_id}/dbs/${each.value.database}"
}
```

- The account has `local_authentication_disabled = true`, which disables keys.
- Never give apps control-plane roles that can list keys.
- Create custom role definitions (`azurerm_cosmosdb_sql_role_definition`) for container-scoped least privilege when needed.

### 11.6 DynamoDB — IAM only

- One generated IAM policy per (app, table, tier), with actions per tier:
  - **ro:** `GetItem`, `BatchGetItem`, `Query`, `Scan`, `DescribeTable`
  - **rw:** ro + `PutItem`, `UpdateItem`, `DeleteItem`, `BatchWriteItem`, `ConditionCheckItem`
- Resources: the table ARN and `"${table_arn}/index/*"`.
- Optional tenant isolation with the `dynamodb:LeadingKeys` condition.
- Grant `kms:Decrypt` and `kms:GenerateDataKey` on the table CMK **via the key policy grant pattern** (`kms:ViaService = dynamodb.<region>.amazonaws.com`).

---

## 12. Encryption and secrets

### 12.1 At rest / in transit — required settings (examples)

**AWS RDS PostgreSQL (L1 excerpt)**

```hcl
resource "aws_db_parameter_group" "this" {
  name   = "${var.name}-pg16"
  family = "postgres16"

  parameter { name = "rds.force_ssl"             value = "1" }
  parameter { name = "ssl_min_protocol_version"  value = "TLSv1.2" }
  parameter {
    name         = "shared_preload_libraries"
    value        = "pg_stat_statements,pgaudit"
    apply_method = "pending-reboot"
  }
  parameter { name = "pgaudit.log"               value = "ddl,role" }
  parameter { name = "log_connections"           value = "1" }
  parameter { name = "log_disconnections"        value = "1" }
}

resource "aws_db_instance" "this" {
  identifier                          = var.name
  engine                              = "postgres"
  engine_version                      = var.engine_version
  instance_class                      = var.instance_class
  allocated_storage                   = var.allocated_storage
  max_allocated_storage               = var.max_allocated_storage
  storage_type                        = "gp3"
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  manage_master_user_password         = true
  master_user_secret_kms_key_id       = var.secrets_kms_key_arn
  username                            = "dbmaster"
  iam_database_authentication_enabled = true
  db_subnet_group_name                = var.db_subnet_group_name
  vpc_security_group_ids              = [aws_security_group.this.id]
  publicly_accessible                 = false
  multi_az                            = var.tier == "tier1"
  parameter_group_name                = aws_db_parameter_group.this.name
  ca_cert_identifier                  = "rds-ca-rsa2048-g1"
  backup_retention_period             = local.backup_policy[var.tier].retention_days
  backup_window                       = "17:00-18:00"
  maintenance_window                  = "sun:18:30-sun:19:30"
  copy_tags_to_snapshot               = true
  delete_automated_backups            = false
  deletion_protection                 = true
  skip_final_snapshot                 = false
  final_snapshot_identifier           = "${var.name}-final"
  performance_insights_enabled        = true
  performance_insights_kms_key_id     = var.kms_key_arn
  monitoring_interval                 = 30
  monitoring_role_arn                 = var.enhanced_monitoring_role_arn
  enabled_cloudwatch_logs_exports     = ["postgresql", "upgrade", "iam-db-auth-error"]
  auto_minor_version_upgrade          = true
  tags                                = var.tags

  lifecycle {
    prevent_destroy = true
  }
}
```

**Azure PostgreSQL Flexible (L1 excerpt)**

```hcl
resource "azurerm_postgresql_flexible_server" "this" {
  name                          = var.name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  version                       = var.pg_version
  sku_name                      = var.sku_name
  storage_mb                    = var.storage_mb
  auto_grow_enabled             = true
  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = var.private_dns_zone_id
  public_network_access_enabled = false
  backup_retention_days         = local.backup_policy[var.tier].retention_days
  geo_redundant_backup_enabled  = local.backup_policy[var.tier].geo_redundant

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = compact([var.cmk_identity_id, var.geo_cmk_identity_id])
  }

  customer_managed_key {
    key_vault_key_id                     = var.cmk_versionless_key_id
    primary_user_assigned_identity_id    = var.cmk_identity_id
    geo_backup_key_vault_key_id          = var.geo_cmk_versionless_key_id   # required when geo backup + CMK
    geo_backup_user_assigned_identity_id = var.geo_cmk_identity_id
  }

  dynamic "high_availability" {
    for_each = var.tier == "tier1" ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  maintenance_window {
    day_of_week  = 0
    start_hour   = 2
    start_minute = 0
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [zone, high_availability[0].standby_availability_zone]
  }
}

locals {
  server_parameters = merge({
    require_secure_transport   = "on"
    ssl_min_protocol_version   = "TLSv1.2"
    shared_preload_libraries   = "pg_stat_statements,pgaudit"
    "pgaudit.log"              = "ddl,role"
    log_connections            = "on"
    log_disconnections         = "on"
    "azure.extensions"         = upper(join(",", sort(var.allowed_extensions)))  # union from requests
  }, var.extra_parameters)
}

resource "azurerm_postgresql_flexible_server_configuration" "this" {
  for_each  = local.server_parameters
  name      = each.key
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = each.value
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "dba" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.dba_group_object_id
  principal_name      = var.dba_group_name
  principal_type      = "Group"
}

resource "azurerm_postgresql_flexible_server_active_directory_administrator" "pipeline_l3" {
  server_name         = azurerm_postgresql_flexible_server.this.name
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  object_id           = var.pipeline_l3_object_id
  principal_name      = var.pipeline_l3_name
  principal_type      = "ServicePrincipal"
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                       = "to-law"
  target_resource_id         = azurerm_postgresql_flexible_server.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  enabled_log { category_group = "audit" }
  enabled_log { category_group = "allLogs" }
  enabled_metric { category = "AllMetrics" }   # verify block name for pinned azurerm (metric vs enabled_metric)
}
```

Equivalent mandatory settings for the other engines:

- **Azure SQL:**
  - `azurerm_mssql_server_transparent_data_encryption` with `key_vault_key_id`.
  - `azuread_authentication_only = true`.
  - `public_network_access_enabled = false` + PE.
  - Auditing (`azurerm_mssql_server_extended_auditing_policy`, `log_monitoring_enabled = true`).
  - Defender (`azurerm_mssql_server_security_alert_policy`) and vulnerability assessment.
  - Database-level CMK for restricted DBs if needed.
- **Cosmos:**
  - `key_vault_key_id` (CMK) with `default_identity_type` set to the UAMI.
  - `local_authentication_disabled = true`, `public_network_access_enabled = false`, `minimal_tls_version = "Tls12"`.
  - `backup { type = "Continuous", tier = "Continuous30Days" }` for tier1.
  - Diagnostic settings.
- **DynamoDB:**
  - `server_side_encryption { enabled = true, kms_key_arn = ... }`
  - `point_in_time_recovery { enabled = true }`
  - `deletion_protection_enabled = true`
- **Redis / ElastiCache:** TLS only, at-rest encryption with CMK, Entra/RBAC users, no non-TLS port.

### 12.2 Secrets (only when identity auth is impossible)

Order of preference:

1. **Identity auth.** No secret at all.
2. **Engine-managed secret:** RDS `manage_master_user_password = true` (Secrets Manager plus built-in rotation).
3. **Rotation-owned secret.** Terraform creates the login role **without a password** (or with `ignore_changes = [password]`) plus the secret container and the rotation schedule. The rotation function (AWS Secrets Manager multi-user rotation Lambda / Azure Function + Key Vault event) sets and rotates the password. Terraform never sees it.
4. **Write-only bootstrap.** For a one-time value, use `ephemeral "random_password"` + write-only arguments, with a `*_wo_version` bump to rotate:

```hcl
ephemeral "random_password" "legacy_app" {
  length           = 40
  special          = true
  override_special = "-_=+.%"
}

resource "aws_secretsmanager_secret" "legacy_app" {
  name       = "db/${var.server}/${var.db}/legacy_app"
  kms_key_id = var.secrets_kms_key_arn
}

resource "aws_secretsmanager_secret_version" "legacy_app" {
  secret_id                = aws_secretsmanager_secret.legacy_app.id
  secret_string_wo         = jsonencode({ username = "legacy_app", password = ephemeral.random_password.legacy_app.result })
  secret_string_wo_version = var.legacy_app_password_version   # bump to rotate
}
# Azure equivalent: azurerm_key_vault_secret { value_wo, value_wo_version }.
# Use the engine provider's write-only password argument if the pinned version supports it;
# otherwise use option 3.
```

Forbidden:
- `random_password` (non-ephemeral) for DB passwords.
- Passwords in `.tfvars`, outputs, or CI logs.
- `sensitive` outputs of passwords.

---

## 13. Backup, restore and DR

### 13.1 Tier policy (single source of truth in `modules/_shared/backup-policy`)

| Tier | RPO | RTO | PITR retention | Long-term | Cross-region | Cross-account/sub (immutable) | Drill |
|---|---|---|---|---|---|---|---|
| tier1 | ≤ 5 min | ≤ 1 h | 35 days | monthly × 12, yearly × 7 | ✅ | ✅ (vault lock) | monthly |
| tier2 | ≤ 15 min | ≤ 4 h | 14 days | monthly × 6 | ✅ | ✅ | quarterly |
| tier3 | ≤ 24 h | ≤ 24 h | 7 days | – | optional | optional | semi-annual |

For **shared servers**, the server tier is the **highest tier** of any DB placed on it. L1 computes this from the requests.

**Per-DB logical backups (multi-DB servers, tier1).** Server-level PITR restores *all* databases. Add a scheduled job that takes a nightly `pg_dump -Fd` per DB into immutable storage (S3 Object Lock / immutable blob), encrypted with a CMK. This enables fast single-DB restore and long-term per-DB retention. The job loops over the same request inventory.

### 13.2 Restore principles

1. **Always restore to a new resource.** Never in place.
2. A restore is triggered by a YAML in `restores/` through a PR. It needs a ticket, a reason, a restore time (UTC), and a mode. The pipeline requires **two DBA approvals** for prod.
3. Restored resources inherit the **same encryption, network, classification and tags**, plus:
   - `purpose=restore`
   - `restore-ticket=<id>`
   - `ttl=<UTC timestamp>`
4. Until validation passes, access to restored resources is **DBA-only**. Do not apply L3 to them yet.
5. A nightly `cleanup-ttl` workflow destroys expired restore stacks and reports them.
6. Every restore emits an audit record (who, what, when, source, point in time, result, measured RTO).

### 13.3 Restore modes

| Mode | When | Engines |
|---|---|---|
| `full-server` | server-level corruption, region issue, DR | RDS/Aurora, PG Flex, MySQL Flex, Cosmos account, SQL MI |
| `single-db` | one DB on a **shared** server must be rolled back | PG/MySQL (via temp server + dump/restore, or nightly logical backup), Azure SQL DB (native per-DB PITR), Cosmos (restore DB/containers into new account, then copy), DynamoDB (table-level native) |
| `drill` | scheduled test, auto-destroy | all |

### 13.4 Restore request (YAML)

```yaml
# restores/2026-10-10-payment.yaml
apiVersion: dbplatform/v1
kind: RestoreRequest
metadata:
  ticket: INC-2026-1001
  requested_by: someone@example.com
  reason: "Bad deploy deleted rows in payment.app.transactions at 09:42 UTC"
spec:
  cloud: azure
  env: prod
  server: psql-acme-prod-sea-shared01
  mode: single-db
  database: payment
  restore_time_utc: "2026-10-10T09:40:00Z"
  cutover: manual                # manual | dns-swap | rename
  ttl_hours: 72
```

### 13.5 Restore modules (examples)

**AWS RDS PITR → new instance**

```hcl
resource "aws_db_instance" "restored" {
  identifier                          = "${var.source_identifier}-r${var.restore_tag}"
  instance_class                      = var.instance_class
  db_subnet_group_name                = var.db_subnet_group_name
  vpc_security_group_ids              = var.restore_security_group_ids   # DBA/runner only until validated
  parameter_group_name                = var.parameter_group_name
  storage_encrypted                   = true
  kms_key_id                          = var.kms_key_arn
  iam_database_authentication_enabled = true
  manage_master_user_password         = true
  publicly_accessible                 = false
  multi_az                            = var.mode == "full-server"
  deletion_protection                 = var.mode == "full-server"
  skip_final_snapshot                 = var.mode != "full-server"
  copy_tags_to_snapshot               = true

  restore_to_point_in_time {
    source_db_instance_identifier = var.source_identifier
    restore_time                  = var.restore_time_utc       # or use_latest_restorable_time = true
  }

  tags = merge(var.tags, { purpose = "restore", restore-ticket = var.ticket, ttl = var.ttl_utc })
}
```

**Azure PG Flexible PITR → new server**

```hcl
resource "azurerm_postgresql_flexible_server" "restored" {
  name                              = "${var.source_name}-r${var.restore_tag}"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  create_mode                       = "PointInTimeRestore"
  source_server_id                  = var.source_server_id
  point_in_time_restore_time_in_utc = var.restore_time_utc
  delegated_subnet_id               = var.delegated_subnet_id
  private_dns_zone_id               = var.private_dns_zone_id
  public_network_access_enabled     = false

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = false
    tenant_id                     = var.tenant_id
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.cmk_identity_id]
  }

  customer_managed_key {
    key_vault_key_id                  = var.cmk_versionless_key_id
    primary_user_assigned_identity_id = var.cmk_identity_id
  }

  tags = merge(var.tags, { purpose = "restore", restore-ticket = var.ticket, ttl = var.ttl_utc })
}
```

**Azure SQL single DB (native per-DB PITR)**

```hcl
resource "azurerm_mssql_database" "restored" {
  name                        = "${var.database_name}_r${var.restore_tag}"
  server_id                   = var.server_id
  create_mode                 = "PointInTimeRestore"
  creation_source_database_id = var.source_database_id
  restore_point_in_time       = var.restore_time_utc
  elastic_pool_id             = var.elastic_pool_id
  tags                        = merge(var.tags, { purpose = "restore", ttl = var.ttl_utc })
}
```

**Cosmos DB (continuous backup) → new account with selected DB/containers**

```hcl
data "azurerm_cosmosdb_restorable_database_accounts" "src" {
  name     = var.source_account_name
  location = var.location
}

resource "azurerm_cosmosdb_account" "restored" {
  name                          = "${var.source_account_name}-r${var.restore_tag}"
  resource_group_name           = var.resource_group_name
  location                      = var.location
  offer_type                    = "Standard"
  create_mode                   = "Restore"
  local_authentication_disabled = true
  public_network_access_enabled = false
  # consistency_policy, geo_location, identity, key_vault_key_id: same as source

  backup {
    type = "Continuous"
    tier = "Continuous30Days"
  }

  restore {
    source_cosmosdb_account_id = data.azurerm_cosmosdb_restorable_database_accounts.src.accounts[0].id
    restore_timestamp_in_utc   = var.restore_time_utc
    database {
      name             = var.database_name
      collection_names = var.container_names
    }
  }
}
```

**DynamoDB PITR → new table**

```hcl
resource "aws_dynamodb_table" "restored" {
  name                = "${var.source_table}-r${var.restore_tag}"
  restore_source_name = var.source_table
  restore_date_time   = var.restore_time_utc
  billing_mode        = var.billing_mode
  hash_key            = var.hash_key
  range_key           = var.range_key
  # attribute/GSI definitions must match the source

  server_side_encryption {
    enabled     = true
    kms_key_arn = var.kms_key_arn
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, { purpose = "restore", ttl = var.ttl_utc })
}
```

### 13.6 Single-DB restore on a shared PostgreSQL/MySQL server (the hard case)

Pipeline steps (`.github/workflows/restore.yml`, `mode: single-db`):

1. **Plan the restore stack.** Create a temporary PITR server (13.5) in the restore subnet, with DBA-only access.
2. **Add a restore entry to L2** (generated, not hand-written). Create the target database `<db>_r<tag>` with `role_set = <db>`, which reuses the source DB's group roles, so its owner is `<db>_owner` and the grants are identical.
3. **Copy only that DB** from the temp server to the target DB with `scripts/restore-single-db-pg.sh`.
4. **Validate** with `scripts/validate-restore.sh`:
   - Schema diff against the source.
   - Row counts per table.
   - App-team-provided `validation.sql` if present.
   - The result goes into the PR as a comment.
5. **Cut over** after a manual approval gate. Choose one:
   - `manual`: the app team switches the connection string or DB name through config. **Recommended.**
   - `rename` in a maintenance window: terminate sessions, `ALTER DATABASE <db> RENAME TO <db>_old_<tag>`, `ALTER DATABASE <db>_r<tag> RENAME TO <db>`. Then reconcile Terraform state with the generated `removed {}` / `import {}` blocks, documented in the runbook.
6. **Destroy** the temporary server immediately after the copy. Drop `<db>_old_<tag>` after its TTL, behind a separate PR.

```bash
#!/usr/bin/env bash
# scripts/restore-single-db-pg.sh
set -euo pipefail
: "${TMP_HOST:?}" "${DST_HOST:?}" "${DB:?}" "${RESTORE_TAG:?}"

[[ "$DB" =~ ^[a-z][a-z0-9_]{2,30}$ ]] || { echo "invalid db name"; exit 2; }
TARGET_DB="${DB}_r${RESTORE_TAG}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

export PGSSLMODE=verify-full
# PGPASSWORD is an Entra / IAM token injected by the pipeline (masked).

echo "==> dump ${DB} from temporary PITR server"
pg_dump --host="$TMP_HOST" --dbname="$DB" \
  --format=directory --jobs=4 --no-owner --no-acl \
  --file="$WORK/dump"

echo "==> restore into ${TARGET_DB} as ${DB}_owner"
pg_restore --host="$DST_HOST" --dbname="$TARGET_DB" \
  --jobs=4 --no-owner --no-acl --role="${DB}_owner" \
  --exit-on-error "$WORK/dump"

echo "==> re-apply grants for existing objects"
# Grants come from Terraform L3 (postgresql_grant with objects = []) re-applied on TARGET_DB by the pipeline.
```

### 13.7 Restore drills (automated)

`.github/workflows/restore-drill.yml` runs on a schedule per tier. For each server due for a drill, it does the following:

1. Restore the latest restorable time to a temporary server or account.
2. **Loop over every database on that server**, using the same request inventory:
   - Connect with the drill identity.
   - Run the standard checks: connectable, schema present, row counts > 0 for key tables, extensions present, encryption status = CMK.
3. Measure **RTO** (start → all DBs validated) and compare it with the tier target.
4. Destroy everything and post a report (Markdown + JSON) as a workflow artifact and to ChatOps. Open an issue automatically if a check fails or RTO is exceeded.

### 13.8 DR

- **AWS:** cross-region automated backup replication (`aws_db_instance_automated_backups_replication`) or an Aurora Global Database for tier1. AWS Backup copies to the isolated account with a multi-region KMS key.
- **Azure:**
  - PG/MySQL: geo-redundant backup + geo-restore (needs the geo CMK). Read replicas in the paired region for tier1 if required.
  - Azure SQL: failover groups.
  - Cosmos: multi-region writes/reads per tier.
- The DNS CNAME layer (section 8) makes regional failover a record change.

---

## 14. Security controls checklist (agent must implement and map to code)

Produce `docs/security-controls.md`. It maps each control to the file and resource that implements it and to the policy or test that enforces it.

| # | Control |
|---|---|
| S1 | No public network access on any DB, KV, or storage. Private endpoints and private DNS only. |
| S2 | CMK at rest for DB, backups, logs, secrets, and state. Key rotation on. Purge/deletion protection on. |
| S3 | TLS ≥ 1.2 enforced server-side. Clients use `verify-full`. CA bundle pinned in the runner image. |
| S4 | Identity-based auth for admins, apps, and engineers. Password auth disabled where the engine allows. |
| S5 | No passwords in state, vars, outputs, or logs (ephemeral / write-only / rotation-owned). |
| S6 | Least-privilege role model. No app uses owner or admin. No direct grants to login users. |
| S7 | `REVOKE ... FROM PUBLIC` on every PG database and on the public schema. |
| S8 | Break-glass rw only via PIM / time-bound access, with an alert on use. |
| S9 | Audit logs (pgaudit / SQL auditing / Cosmos diagnostics / CloudTrail data events) sent to SIEM with ≥ 1-year retention. |
| S10 | Threat detection enabled (Defender plans, GuardDuty RDS Protection). |
| S11 | Separation of duties: per-layer pipeline identities. L2/L3 cannot delete servers. L1 has no data-plane access. |
| S12 | State backends encrypted, private, versioned, and locked. L3 state access restricted. |
| S13 | OIDC federation only. No long-lived cloud credentials in CI. |
| S14 | Supply chain: pinned versions, lockfile hashes, pinned action SHAs, `checkov`/`trivy` in CI. |
| S15 | Deletion safety: `prevent_destroy`, `deletion_protection`, policy-blocked deletes, immutable backup copies. |
| S16 | SQL injection-safe automation: every YAML identifier regex-validated before use in SQL or shell. |
| S17 | Restored resources inherit encryption and network, carry a TTL, and are DBA-only until validated. |
| S18 | Drift detection nightly with alerting. |
| S19 | Org-level guardrails (SCPs / Azure Policy) as a second line of defense. |

---

## 15. Observability baseline (per server)

**Alerts** (Azure metric alerts / CloudWatch alarms → action group / SNS → ChatOps / on-call):

- CPU > 80% for 15 min
- Memory pressure
- Free storage < 15% (warning) / < 10% (critical)
- IOPS / throughput saturation
- Connections > 80% of `max_connections`
- Replication lag > threshold (tier-based)
- Deadlocks > 0
- Failed logins spike
- Backup failure / no restorable point within RPO
- Cosmos: 429 rate > 1%, normalized RU > 90%
- DynamoDB: throttled requests > 0, PITR disabled
- Any `eng_rw` role membership activation (security alert)

Dashboards per server, generated from the same inventory. Log retention by classification.

---

## 16. CI/CD and policy as code

### 16.1 Workflows

| Workflow | Trigger | Does |
|---|---|---|
| `pr.yml` | PR | Schema-validate YAML, duplicate check, fmt, tflint, checkov, `terraform test`, detect changed stacks, plan per stack on the right runner, conftest on plan JSON, infracost, PR comment |
| `apply.yml` | push to `main` | Apply changed stacks in layer order L0→L1→L2→L3. `environment: <env>` with required reviewers for prod. |
| `drift.yml` | nightly | `plan -detailed-exitcode` on all stacks, then report and open an issue |
| `restore.yml` | PR adding `restores/*.yaml` + manual approval | Section 13 |
| `restore-drill.yml` | schedule | Section 13.7 |
| `cleanup-ttl.yml` | nightly | Destroy expired restore stacks |

### 16.2 Example `pr.yml` (core parts)

```yaml
name: pr
on:
  pull_request:
    paths: ["live/**", "modules/**", "requests/**", "restores/**", "policies/**"]

permissions:
  id-token: write
  contents: read
  pull-requests: write

jobs:
  static:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinned-sha>
      - uses: hashicorp/setup-terraform@<pinned-sha>
        with: { terraform_version: "1.11.x" }
      - run: terraform fmt -check -recursive
      - run: check-jsonschema --schemafile requests/_schema/request.schema.json requests/**/*.yaml
      - run: ./scripts/check-duplicates.sh
      - run: tflint --recursive
      - run: checkov -d modules --quiet
      - run: |
          for m in $(find modules -name '*.tftest.hcl' -exec dirname {} \; | sort -u); do
            (cd "$m" && terraform init -backend=false && terraform test)
          done
      - run: conftest verify -p policies

  detect:
    runs-on: ubuntu-latest
    outputs:
      stacks: ${{ steps.d.outputs.stacks }}
    steps:
      - uses: actions/checkout@<pinned-sha>
        with: { fetch-depth: 0 }
      - id: d
        run: ./scripts/detect-changed-stacks.sh "${{ github.event.pull_request.base.sha }}" >> "$GITHUB_OUTPUT"
        # Outputs JSON: [{path, cloud, env, layer, runner, needs_db_token}]
        # A change in requests/** maps to the 20-databases and 30-access stacks of the referenced server
        # (and 10-server if extensions/tier changed).

  plan:
    needs: [static, detect]
    if: needs.detect.outputs.stacks != '[]'
    strategy:
      fail-fast: false
      matrix:
        stack: ${{ fromJson(needs.detect.outputs.stacks) }}
    runs-on: [self-hosted, "${{ matrix.stack.runner }}"]
    environment: ${{ matrix.stack.env }}-plan
    steps:
      - uses: actions/checkout@<pinned-sha>
      - if: matrix.stack.cloud == 'azure'
        uses: azure/login@<pinned-sha>
        with:
          client-id: ${{ vars[format('AZ_CLIENT_ID_{0}_{1}', matrix.stack.env, matrix.stack.layer)] }}
          tenant-id: ${{ vars.AZ_TENANT_ID }}
          subscription-id: ${{ vars[format('AZ_SUB_{0}', matrix.stack.env)] }}
      - if: matrix.stack.cloud == 'aws'
        uses: aws-actions/configure-aws-credentials@<pinned-sha>
        with:
          role-to-assume: ${{ vars[format('AWS_ROLE_{0}_{1}', matrix.stack.env, matrix.stack.layer)] }}
          aws-region: ${{ matrix.stack.region }}
      - name: DB access token (Azure PG)
        if: matrix.stack.cloud == 'azure' && matrix.stack.needs_db_token
        run: |
          TOKEN=$(az account get-access-token --resource-type oss-rdbms --query accessToken -o tsv)
          echo "::add-mask::$TOKEN"
          echo "PGPASSWORD=$TOKEN" >> "$GITHUB_ENV"
      - name: Plan
        working-directory: ${{ matrix.stack.path }}
        run: |
          terragrunt plan -out=tfplan -lock-timeout=5m -parallelism=4
          terragrunt show -json tfplan > tfplan.json
      - name: Policy
        run: conftest test ${{ matrix.stack.path }}/tfplan.json -p policies --all-namespaces
      # Post a summarized plan as a PR comment. Never upload raw plan files as public artifacts.
```

### 16.3 Example policies (Rego v1)

```rego
# policies/deny_destroy.rego
package dbplatform.destroy

import rego.v1

protected := {
  "aws_db_instance", "aws_rds_cluster", "aws_dynamodb_table", "aws_kms_key",
  "azurerm_postgresql_flexible_server", "azurerm_mssql_server", "azurerm_mssql_database",
  "azurerm_cosmosdb_account", "azurerm_cosmosdb_sql_database", "azurerm_cosmosdb_sql_container",
  "azurerm_key_vault", "azurerm_key_vault_key",
  "postgresql_database", "postgresql_schema",
}

deny contains msg if {
  rc := input.resource_changes[_]
  protected[rc.type]
  "delete" in rc.change.actions
  not data.exceptions.break_glass[rc.address]
  msg := sprintf("BLOCKED: %s would be deleted/replaced. Requires break-glass label + 2 DBA approvals.", [rc.address])
}
```

```rego
# policies/network_encryption.rego
package dbplatform.baseline

import rego.v1

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "aws_db_instance"
  after := rc.change.after
  after.publicly_accessible == true
  msg := sprintf("%s: publicly_accessible must be false", [rc.address])
}

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "aws_db_instance"
  rc.change.after.storage_encrypted != true
  msg := sprintf("%s: storage_encrypted must be true", [rc.address])
}

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type in {"azurerm_postgresql_flexible_server", "azurerm_mssql_server", "azurerm_cosmosdb_account"}
  rc.change.after.public_network_access_enabled == true
  msg := sprintf("%s: public network access must be disabled", [rc.address])
}

deny contains msg if {
  rc := input.resource_changes[_]
  rc.type == "postgresql_role"
  rc.change.after.superuser == true
  msg := sprintf("%s: superuser roles are forbidden", [rc.address])
}
```

Every policy needs `*_test.rego` with positive and negative cases.

### 16.4 CODEOWNERS

```
/modules/**        @org/dba-team
/live/**           @org/dba-team
/policies/**       @org/dba-team @org/security
/requests/<team>/  @org/dba-team @org/<team>
/restores/**       @org/dba-team
```

---

## 17. Testing strategy

1. **Unit:** `terraform test` with `mock_provider` for every module.
   - Validations: names, classification placement, connection budget.
   - Expected resource counts for N databases × M schemas × tiers.
   - Key stability: adding one DB must not change the keys of the others.

```hcl
# modules/databases/postgres/tests/guardrails.tftest.hcl
mock_provider "postgresql" {}

variables {
  server_max_connections         = 200
  reserved_connections           = 20
  max_databases_per_server       = 20
  server_allowed_classifications = ["internal", "confidential"]
  databases = {
    payment = { team = "payment", data_classification = "confidential", tier = "tier1", connection_limit = 100, access = {} }
    order   = { team = "order",   data_classification = "internal",     tier = "tier2", connection_limit = 50,  access = {} }
  }
}

run "creates_five_group_roles_per_db" {
  command = plan
  assert {
    condition     = length(postgresql_role.group) == 10
    error_message = "Expected 5 tiers x 2 databases."
  }
}

run "rejects_connection_budget_overflow" {
  command = plan
  variables {
    databases = {
      a = { team = "t", data_classification = "internal", tier = "tier3", connection_limit = 150, access = {} }
      b = { team = "t", data_classification = "internal", tier = "tier3", connection_limit = 150, access = {} }
    }
  }
  expect_failures = [terraform_data.guardrails]
}

run "rejects_restricted_on_shared_server" {
  command = plan
  variables {
    databases = {
      hr = { team = "hr", data_classification = "restricted", tier = "tier1", connection_limit = 10, access = {} }
    }
  }
  expect_failures = [terraform_data.guardrails]
}
```

2. **Policy:** `conftest verify` with fixture plan JSONs.
3. **Integration (non-prod, nightly):** apply into a `sandbox` env, run connectivity and permission tests, then destroy:
   - `rw` can insert, `ro` cannot.
   - The DB A principal cannot connect to DB B.
   - `PUBLIC` cannot connect.
   - A migration as owner creates a table and `rw` automatically gets access to it.
4. **Restore drill** (section 13.7) is the end-to-end test of backups.

---

## 18. Documentation deliverables

- `README.md`: purpose, architecture diagram (mermaid), how to request a DB, how to request access, how to request a restore, SLAs per tier.
- `docs/adr/*`: layering, versions, auth strategy, shared vs dedicated servers, secrets strategy, restore strategy, role model.
- `docs/runbooks/*`:
  - `onboarding-new-server.md`
  - `restore-full-server.md`
  - `restore-single-db.md`
  - `break-glass.md`
  - `rotate-cmk.md`
  - `rotate-secret.md`
  - `decommission-database.md` (REASSIGN/DROP OWNED, final dump, retention)
  - `major-version-upgrade.md`
  - `import-existing-db.md` (using `import {}` blocks)
- `docs/security-controls.md` (section 14).
- `terraform-docs`-generated README per module.

---

## 19. Coding standards

- **Naming:** Azure follows CAF abbreviations (`psql-`, `sql-`, `sqldb-`, `cosmos-`, `kv-`, `rg-`, `id-`). AWS uses `<org>-<env>-<region>-<engine>-<name>`. Both are generated by a shared `naming` module. Never hand-write names.
- **Required tags:** `owner-team`, `cost-center`, `env`, `data-classification`, `tier`, `managed-by=terraform`, `request`, `repo`.
- **Module layout:** every module has `versions.tf`, `variables.tf` (typed, described, validated, `optional()` defaults), `main.tf`, `outputs.tf` (no secrets), `README.md`, and `tests/`.
- **Inputs and outputs:** no `any` except for pass-through YAML blocks, and those must be validated. Outputs are minimal and documented.
- **Iteration:** `for_each` with stable keys. `moved {}` for refactors. `import {}` for adoption.
- **Lifecycle:** `prevent_destroy` on stateful resources. Use `ignore_changes` only with a comment explaining why.
- **Code style:** no provisioners except the documented SQL bootstrap cases. Every interpolated identifier is regex-validated. Comments explain *why*, not *what*.

---

## 20. Working method and phases

Work in phases. At the end of each phase, output:
1. The file tree.
2. Every file in full, with no `...` placeholders except documented `TODO(verify)` items.
3. How to run it.
4. Test results or the commands to run them.
5. The list of `TODO(verify)` items.
6. Risks and open questions.

**Stop and wait for review before the next phase.**

| Phase | Deliverables | Acceptance criteria |
|---|---|---|
| **P0 Design** | ADRs 0001–0007, `architecture.md`, naming/tagging module spec, request JSON Schema, tier policy | Reviewed by DBA + Security |
| **P1 Foundation** | state backends, OIDC identities per layer, CI runners in VPC/VNet, network + private DNS, KMS/KV, backup vaults (immutable, cross-account), observability, org policies, `pr.yml`/`apply.yml`/`drift.yml` skeletons | Runner can reach a private test endpoint. Plan/apply via OIDC works. Policies block a public DB in a test fixture. |
| **P2 PostgreSQL reference** | Azure PG Flexible + AWS RDS PG: L1/L2/L3 modules, multi-DB-per-server loops, guardrails, Entra/IAM auth, restore modules (full + single-db), restore + drill + TTL workflows, alerts, tests | Two DBs on one server are isolated (proved by an integration test). Single-DB restore drill passes within the tier RTO. No secrets in state (grep the state in the test env). |
| **P3 SQL family** | Azure SQL DB + Elastic Pool, SQL MI, RDS MySQL, RDS SQL Server | Same capability contract, tests green |
| **P4 NoSQL** | Cosmos NoSQL (+ Mongo), DynamoDB, DocumentDB, Redis/ElastiCache | RBAC/IAM least privilege proved by tests. PITR restore drill passes. |
| **P5 Operations** | dashboards, cost reports, access expiry automation, decommission flow, import of existing DBs | Runbooks executed once in non-prod |

---

## 21. Anti-patterns (forbidden — reject them in review)

- Server and DB-level provider in the same state.
- `count` for databases, roles, or grants.
- Grants to `PUBLIC`, or to login users directly.
- Apps using admin/master/owner credentials.
- `random_password` (non-ephemeral) or plaintext passwords anywhere.
- Public endpoints "temporarily".
- Firewall rules `0.0.0.0–255.255.255.255` or "Allow Azure services".
- Restoring in place, or overwriting the prod DB with a restore.
- Restored resources without TTL or tags.
- Unpinned providers, modules, or actions.
- Long-lived cloud keys in CI.
- Terraform managing tables or data.
- Silent `ignore_changes = all`.
- Copy-pasted per-env code instead of modules + inputs.

---

## 22. Start now

Begin with **Phase P0**:
1. Restate the Inputs (section 0) with the defaults you applied.
2. List the assumptions you made and the questions that would change the design.
3. Produce the ADRs, the architecture diagram, the request/restore JSON Schemas, and the naming/tagging/backup-policy module specs.
4. Stop and wait for approval.
