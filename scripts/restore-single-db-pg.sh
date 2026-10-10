#!/usr/bin/env bash
# Single-database restore for a Postgres server that hosts many databases
# (spec section 13.1/13.3). Server-level PITR restores EVERY database on
# the server, which is too broad a blast radius for "roll back one
# tenant's table". Instead: restore the whole server to a throwaway
# instance via Terraform (modules/restore/aws-rds-pitr or azure-pg-pitr),
# pg_dump just the one database off it, then pg_restore that dump into a
# NEW database on the production server (never in place, per spec 13.2).
#
# Usage: restore-single-db-pg.sh <restored-host> <database> <target-host> <target-database>
set -euo pipefail

RESTORED_HOST="${1:?restored instance host required}"
SOURCE_DB="${2:?database name required}"
TARGET_HOST="${3:?production server host required}"
TARGET_DB="${4:?new target database name required}"

if [[ ! "$SOURCE_DB" =~ ^[a-z][a-z0-9_]{2,30}$ ]] || [[ ! "$TARGET_DB" =~ ^[a-z][a-z0-9_]{2,30}$ ]]; then
  echo "Refusing: database name does not match ^[a-z][a-z0-9_]{2,30}\$" >&2
  exit 1
fi

DUMP_DIR="$(mktemp -d)"
trap 'rm -rf "$DUMP_DIR"' EXIT

echo "Dumping ${SOURCE_DB} from throwaway restore host ${RESTORED_HOST}..."
pg_dump -h "$RESTORED_HOST" -d "$SOURCE_DB" -Fd -j 4 -f "$DUMP_DIR/dump"

echo "Target database ${TARGET_DB} must already exist (created by Terraform, owned by \${TARGET_DB}_owner)."
echo "Restoring into ${TARGET_HOST}/${TARGET_DB}..."
pg_restore -h "$TARGET_HOST" -d "$TARGET_DB" -j 4 --no-owner --role="${TARGET_DB}_owner" "$DUMP_DIR/dump"

echo "Done. Validate the data, then cut the application over per the restore request's cutover mode."
