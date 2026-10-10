# Runbook: Break-glass access

Break-glass exists for the cases policy-as-code (`policies/`) would
otherwise block outright: deleting a `prevent_destroy`'d resource,
scheduling KMS key deletion, or an engineer needing `eng_rw` write
access outside PIM's normal eligibility window.

## When to use this

- A production incident requires a write that the standard pipeline
  identity (L0–L3, each deliberately scoped per ADR 0001) cannot
  perform.
- A policy check (section 16.3 of the platform spec) is blocking a
  change that two DBAs agree is correct and urgent.

**Not** for routine schema changes, routine access requests, or
anything that can wait for a normal PR review cycle.

## Procedure

1. Open an incident ticket first. Break-glass without a ticket is not
   auditable and should not happen.
2. Add the `break-glass` label to the PR. This is what the Rego
   policy in `policies/` checks for before allowing a delete/replace
   plan against a protected resource type.
3. Get **two DBA approvals** (not one — this mirrors the two-approval
   rule for restores in spec section 13.2).
4. The break-glass IAM role / Entra group (`grp-dba-break-glass`) is
   the only principal exempted from the KMS `ScheduleKeyDeletion` deny
   statement (see `modules/foundation/aws-kms`) — assume that role
   explicitly for the one action needed, nothing else.
5. File a post-incident note within 24 hours: what was done, why
   normal process couldn't be used, and whether a guardrail needs
   adjusting as a result.

## What this is not

Break-glass is not a way around the passwordless-first policy (ADR
0003) or the layering boundaries (ADR 0001). If you find yourself
reaching for break-glass repeatedly for the same situation, that's a
signal the platform's defaults are wrong for that case — fix the
default, don't normalize the break-glass path.
