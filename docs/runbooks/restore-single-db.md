# Runbook: single-database restore (the hard case)

Rolling back **one** database on a server that otherwise should keep
serving every other tenant — the case that matters most for shared
servers (see [[0004-shared-servers]]) and the one spec section 13.6
calls out by name as "the hard case."

## Which mechanism, per engine

| Engine | Mechanism | Why |
|---|---|---|
| Postgres / MySQL | Temporary full-server PITR restore, then `pg_dump`/`pg_restore` just that one database into a **new** database on the live server (`scripts/restore-single-db-pg.sh`) | No native per-database PITR exists — roles/grants and the WAL/binlog stream are server-wide. |
| Azure SQL Database | Native per-database PITR directly (`modules/restore/azure-sql-db-pitr`) | Azure SQL DB genuinely supports this; no temp server needed. |
| DynamoDB | Native per-table PITR directly (`modules/restore/dynamodb-pitr`) | Same reason — table-level PITR is native. |
| Cosmos DB | Restore into a new **account**, then copy just the needed database/containers out (`modules/restore/cosmos-pitr`) | Cosmos restore is account-scoped; there's no narrower native restore. |

## Procedure (Postgres/MySQL — the actual hard case)

1. **Plan the restore.** Apply `modules/restore/aws-rds-pitr` or
   `azure-pg-pitr` to a temporary server, DBA/runner-access only.
2. **Create the target database** on the **live production server**
   via a normal Terraform change to that server's `20-databases`
   stack: add `<db>_r<tag>` reusing the source database's group roles
   (same owner, same grants) so permissions are identical on day one.
3. **Copy only that one database**:
   ```
   bash scripts/restore-single-db-pg.sh <temp-host> <db> <target-host> <db>_r<tag>
   ```
4. **Validate** with `scripts/validate-restore.sh`: schema diff
   against the source, row counts per table, and any app-team-provided
   `validation.sql`. Post the result as a PR comment.
5. **Cut over**, behind a manual approval gate — pick one:
   - `manual` (**recommended**): the app team repoints its connection
     string/database name through its own config. Lowest risk.
   - `rename`, inside a maintenance window: terminate sessions on the
     original database, `ALTER DATABASE <db> RENAME TO <db>_old_<tag>`,
     then `ALTER DATABASE <db>_r<tag> RENAME TO <db>`. Reconcile
     Terraform state afterward with `moved {}` / `import {}` blocks —
     do not hand-edit state.
6. **Destroy the temporary server immediately** after the copy
   completes — it should not wait for `cleanup-ttl.yml`'s nightly
   sweep once you know the copy succeeded. Drop `<db>_old_<tag>` after
   its TTL, as a **separate** PR (never bundled with the restore PR).

## Common mistakes this runbook exists to prevent

- Restoring the whole server when only one database needed it —
  unnecessarily impacts every other tenant on a shared server.
- Cutting over before `validate-restore.sh` has actually been run and
  its output reviewed by a human, not just "the script didn't error."
- Forgetting step 6's immediate teardown and leaving the temporary
  server running until the nightly TTL sweep finds it — that's extra
  spend and extra attack surface for no reason.
