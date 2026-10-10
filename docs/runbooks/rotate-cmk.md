# Runbook: rotating a customer-managed key (CMK)

Distinct from [rotate-secrets.md](rotate-secrets.md) — this is about
the *encryption key*, not an application credential.

## Automatic rotation (the default — usually nothing to do)

- **AWS KMS** (`modules/foundation/aws-kms`): `enable_key_rotation =
  true` rotates the key material automatically every year. No action
  needed; AWS keeps old key material available to decrypt data
  encrypted under previous versions.
- **Azure Key Vault** (`modules/foundation/azure-keyvault`): each key
  has a `rotation_policy` (`expire_after = "P1Y"`, notified 30 days
  before expiry via `notify_before_expiry = "P30D"`). Key Vault
  creates a new key version automatically on schedule.

For both, **check nothing is pinning a specific key version**
(`key_vault_key_id` should reference the *versionless* key id, which
every module in this repo does — grep for `key_versionless_ids` to
confirm). If a resource pins a specific version, automatic rotation
won't reach it and you're in the manual path below.

## Manual rotation (break-glass / incident response)

Needed only if a key is suspected compromised, or a resource somehow
pinned a specific key version.

1. Open a break-glass PR (see [break-glass.md](break-glass.md)) — key
   rotation outside the automatic schedule is exactly the kind of
   action that policy normally blocks (`kms:ScheduleKeyDeletion` is
   denied except for the break-glass role; manual rotation itself
   isn't denied, but treat it with the same two-approval rigor).
2. **AWS:** `aws kms enable-key-rotation` is already on; to force an
   immediate rotation, there is no direct "rotate now" API — instead
   create a new CMK, update `modules/foundation/aws-kms`'s key policy
   and every consumer's `kms_key_arn` input, re-encrypt existing data
   under the new key (engine-specific — RDS requires a snapshot
   copy with the new KMS key, since you cannot change an existing
   instance's CMK in place), then schedule deletion of the old key
   only after confirming nothing still references it.
3. **Azure:** Key Vault supports rotating a key on demand
   (`az keyvault key rotate`) if you need to force a new version
   before the policy's schedule — downstream resources referencing
   the versionless key id pick it up automatically without a
   Terraform change.
4. Record the rotation (who, why, when, which resources were
   re-encrypted) against the incident ticket.

## What NOT to do

- Never set `kms_key_id`/`key_vault_key_id` to a hardcoded specific
  version — always the versionless/alias form, so automatic rotation
  actually reaches the resource.
- Never delete the old key material immediately after rotation; data
  encrypted under it (including old backups) may still need it to
  decrypt until those backups themselves age out per the tier's
  retention policy ([[0006-restore-strategy]]).
