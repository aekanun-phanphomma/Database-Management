# Security controls

Maps each control from the platform spec (section 14) to the file and
resource that implements it, and to the policy or test that enforces
it. "Enforced by" means a CI check fails if the control is violated;
where that column says "none yet," the control is implemented but not
yet policy-gated — see the Known gaps section.

| # | Control | Implemented by | Enforced by |
|---|---|---|---|
| S1 | No public network access on any DB, KV, or storage. Private endpoints and private DNS only. | `publicly_accessible = false` / `public_network_access_enabled = false` in every L1 module (`modules/aws/sql/*`, `modules/azure/sql/*`, `modules/azure/nosql/*`); private endpoints in `modules/foundation/azure-network-db`, `azure-keyvault` | `policies/public_access_deny.rego` |
| S2 | CMK at rest for DB, backups, logs, secrets, and state. Key rotation on. Purge/deletion protection on. | `modules/foundation/aws-kms` (`enable_key_rotation = true`), `azure-keyvault` (`rotation_policy`, `purge_protection_enabled = true`); every L1 module's `kms_key_arn`/`customer_managed_key` input | `policies/tagging.rego` partially (tag presence only); no policy checks CMK usage directly yet — **gap** |
| S3 | TLS ≥ 1.2 enforced server-side. Clients use `verify-full`. | `rds.force_ssl`/`ssl_min_protocol_version` parameters (`rds-postgres`), `minimum_tls_version = "1.2"` (`mssql-server`, `redis`), `require_secure_transport` (`rds-mysql`, `mysql-flexible`); `sslmode = "verify-full"` in every generated `postgresql` provider block in `live/` | none yet — **gap**, add a Rego check on parameter/config values |
| S4 | Identity-based auth for admins, apps, engineers. Password auth disabled where possible. | `password_auth_enabled = false` (`postgres-flexible`); `azuread_authentication_only = true` (`mssql-server`); `iam_database_authentication_enabled = true` (`rds-postgres`, `rds-mysql`); see [[0003-auth]] | none yet — **gap** |
| S5 | No passwords in state, vars, outputs, or logs. | `ephemeral` blocks throughout (`elasticache`, `mssql-mi`, `mysql-flexible`); see [[0005-secrets-strategy]] | none yet — manual grep of state recommended pre-prod, per spec section 17.3; **gap** |
| S6 | Least-privilege role model. No app uses owner/admin. No direct grants to login users. | [[0007-role-model]]; `modules/access/postgres`, `access/mssql`, `access/mysql`, `access/cosmos-nosql`, `access/dynamodb` | none yet — **gap** |
| S7 | `REVOKE ... FROM PUBLIC` on every PG database and public schema. | `modules/databases/postgres/main.tf` — `postgresql_grant.revoke_public_connect`, `revoke_public_schema` | `tests/databases_postgres_guardrails.tftest.hcl` (indirectly — doesn't assert on the revoke grants specifically; **gap**, add an explicit assertion) |
| S8 | Break-glass rw only via PIM / time-bound access, with an alert on use. | `grp-*-db-eng-rw` groups are PIM-eligible-only per [[0007-role-model]] and `docs/runbooks/break-glass.md` | none yet — alert-on-use not wired; **gap** |
| S9 | Audit logs sent to SIEM with ≥ 1-year retention. | `pgaudit.log` parameters; `azurerm_monitor_diagnostic_setting` in every Azure L1 module; `enabled_cloudwatch_logs_exports` in every AWS L1 module; `modules/foundation/aws-observability`, `azure-observability` | none yet; retention period is `var.log_retention_days` (default 90, **not** 1 year) — **gap**, raise default or make tier-driven |
| S10 | Threat detection enabled (Defender plans, GuardDuty RDS Protection). | **Not implemented** — spec section 8.1/8.2 lists GuardDuty RDS Protection and Defender for Cloud plans as L0 components; no corresponding resource exists in `modules/foundation/*` | — **gap**, needs a new `modules/foundation/aws-guardduty` / `azure-defender` module |
| S11 | Separation of duties: per-layer pipeline identities. L2/L3 cannot delete servers. L1 has no data-plane access. | [[0001-layering]]; `l_layer_role_arns`/`l_layer_app_registration_ids` in `modules/foundation/ci-runner-aws`, `ci-runner-azure` | none yet — IAM policy boundaries for `id-<env>-l0..l3` are referenced by name but not yet defined as Terraform resources; **gap** |
| S12 | State backends encrypted, private, versioned, locked. L3 state access restricted. | `modules/foundation/state-backend` (SSE-KMS + Object Lock on AWS, CMK + AAD-only on Azure) | none yet — L3-state access restriction is documented in [[0001-layering]] but not implemented as a bucket/container policy; **gap** |
| S13 | OIDC federation only. No long-lived cloud credentials in CI. | `azuread_application_federated_identity_credential` in `ci-runner-azure`; AWS runner task role assumes per-layer roles via STS in `ci-runner-aws` | none yet — **gap**, add a policy/lint check that no workflow uses static `AWS_ACCESS_KEY_ID`/`AZURE_CLIENT_SECRET` |
| S14 | Supply chain: pinned versions, lockfile hashes, pinned action SHAs, checkov/trivy in CI. | [[0002-versions]]; `.pre-commit-config.yaml` (checkov hook) | Partially — GitHub Actions in `.github/workflows/*.yml` use `@v4` tags, not pinned SHAs (marked `TODO(verify)` in each workflow) — **gap** |
| S15 | Deletion safety: prevent_destroy, deletion_protection, policy-blocked deletes, immutable backup copies. | `lifecycle { prevent_destroy = true }` + `deletion_protection = true` on every L1/L2 resource; `aws_backup_vault_lock_configuration`, Azure Backup `immutability_state` | `policies/prevent_delete.rego` |
| S16 | SQL injection-safe automation: every YAML identifier regex-validated before use in SQL/shell. | `modules/access/postgres/azure.tf` (`terraform_data.validate_azure_identifiers`); `scripts/restore-single-db-pg.sh`, `check-duplicates.sh` (regex checks) | `terraform_data.validate_azure_identifiers`'s own `precondition` (fails plan, not a separate CI step) |
| S17 | Restored resources inherit encryption/network, carry a TTL, are DBA-only until validated. | [[0006-restore-strategy]]; every `modules/restore/*` module's tagging | `cleanup-ttl.yml` enforces the TTL side; no policy yet checks the tag *shape* itself — **gap** |
| S18 | Drift detection nightly with alerting. | `.github/workflows/drift.yml` | the workflow itself; no separate test |
| S19 | Org-level guardrails (SCPs / Azure Policy) as a second line of defense. | **Not implemented** — spec section 8.1/8.2 lists SCPs and Azure Policy definitions; none exist in this repo yet | — **gap**, out of this repo's current scope (org-management-account concern, not per-env) |

## Known gaps (honest list, not aspirational)

The controls marked **gap** above are real, not placeholders for
future polish text. In priority order, the highest-impact ones to
close next are:
1. **S10/S19** — no threat-detection or org-guardrail modules exist at
   all; these are entire missing modules, not partial implementations.
2. **S11/S12** — the per-layer IAM/Entra role *definitions* (not just
   references by name) and L3 state-access-restriction policies don't
   exist as Terraform resources yet.
3. **S3/S4/S6** — these controls are implemented in the resources but
   have no automated policy check verifying them on every plan; a
   plan that accidentally regresses one would currently pass CI.
4. **S14** — every GitHub Action in `.github/workflows/` is pinned to
   a tag (`@v4`), not a SHA, despite ADR 0002/the spec requiring SHA
   pinning.
