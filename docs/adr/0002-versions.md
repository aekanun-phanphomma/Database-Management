# ADR 0002: Tool and provider version pins

## Status
Accepted — revisit whenever a new major provider version ships.

## Context
Supply-chain hygiene (section 3.10 of the platform spec) requires every
tool, provider, module, and GitHub Action to be pinned, with
`.terraform.lock.hcl` committed including hashes for `linux_amd64`,
`darwin_arm64`, and `windows_amd64`.

`terraform >= 1.11.0` is required specifically because this platform
relies on two 1.11+ features:
- `ephemeral` resources/values (bootstrap passwords, reading
  engine-managed secrets without writing them to state).
- Write-only arguments (`*_wo`, `*_wo_version`) for the rare case where
  Terraform must set a password at all.

## Decision

```hcl
terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  required_providers {
    aws        = { source = "hashicorp/aws",       version = "~> 6.0" }
    azurerm    = { source = "hashicorp/azurerm",   version = "~> 4.0" }
    azuread    = { source = "hashicorp/azuread",   version = "~> 3.0" }
    random     = { source = "hashicorp/random",    version = "~> 3.7" }
    postgresql = { source = "cyrilgdn/postgresql", version = "~> 1.25" }
    mssql      = { source = "PGSSoft/mssql",       version = "~> 0.6" }
    mysql      = { source = "petoju/mysql",        version = "~> 3.0" }
  }
}
```

Terragrunt: latest 0.x stable, pinned exactly in
`.github/workflows/*.yml` and documented in `README.md`.

## Verification policy
No resource argument is used unless it has been checked against the
Terraform Registry docs for the **exact pinned version** above. Where an
argument's name or availability could not be verified against those
docs at authoring time, it is marked in-code as `# TODO(verify): <what
to check>` and listed in the relevant phase's report — never guessed
silently. See `docs/adr/0003-auth.md` for the authentication-specific
verification notes (several resources here are new/renamed across
provider major versions).

## Consequences
- Provider major-version bumps (e.g. `azurerm` 4→5) require a dedicated
  PR that re-verifies every attribute touched by this ADR's modules
  before merging, not a drive-by bump.
- `cyrilgdn/postgresql`, `PGSSoft/mssql`, and `petoju/mysql` are smaller,
  community-maintained providers; pin tightly and track their changelogs
  because breaking changes there are more likely than in `hashicorp/*`.
