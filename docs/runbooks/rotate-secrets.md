# Runbook: Rotating secrets

Per ADR 0003, a static DB password should be rare. This runbook only
applies to the minority of workloads that fell through to options
2–4 of that order.

## Engine-managed secrets (RDS/Aurora master user)

`manage_master_user_password = true` hands rotation to AWS Secrets
Manager's built-in rotation. There is nothing to do manually — verify
the rotation schedule is active:

```
aws secretsmanager describe-secret --secret-id <master_user_secret_arn>
```

If rotation looks stalled, check the rotation Lambda's CloudWatch
logs before touching anything in Terraform state — the secret's value
is never in Terraform state to begin with (ADR 0003), so there is
nothing to fix there.

## Rotation-owned secrets (option 3)

These are created with the login role's password left unmanaged by
Terraform (`lifecycle.ignore_changes = [password]` on the role
resource, or no password set at all plus a rotation Function). To
rotate:

1. Trigger the rotation Lambda/Function for that secret directly
   (do **not** re-run `terraform apply` expecting it to rotate
   anything — Terraform doesn't own the password value).
2. Confirm the new value landed in Secrets Manager / Key Vault and
   that the application picked it up (most app runtimes cache the
   secret; a forced restart or a rotation-aware SDK is required).
3. Revoke the old value only after confirming the new one works —
   most rotation Lambdas do this automatically with a staging/current
   version swap.

## Write-only bootstrap secrets (option 4, last resort)

Bump the `*_wo_version` input (e.g. `legacy_app_password_version` in
the example under spec section 12.2) and re-apply. This generates a
new `ephemeral "random_password"` value and writes it via the
provider's write-only argument — the old value is not retrievable
after this, so confirm the consuming application is ready to pick up
the new value before bumping the version in prod.

## If you're not sure which category a workload is in

Check the database request's PR description — option 4 usage must be
called out explicitly there per ADR 0003. If it isn't documented
anywhere, treat it as a gap: file a ticket to classify it properly
rather than guessing.
