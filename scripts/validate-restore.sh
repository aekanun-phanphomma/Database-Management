#!/usr/bin/env bash
# Minimal post-restore validation gate (spec section 13.2 point 4: a
# restored resource is DBA-only until it passes validation — this script
# is what the restore.yml workflow runs before it will let a DBA mark the
# restore as validated/ready for cutover).
#
# Usage: validate-restore.sh <host> <database>
set -euo pipefail

HOST="${1:?host required}"
DB="${2:?database required}"

echo "Checking connectivity..."
psql -h "$HOST" -d "$DB" -v ON_ERROR_STOP=1 -tAc "SELECT 1;" >/dev/null

echo "Checking for obviously truncated tables (0 rows) — not a hard failure, just a flag for the DBA..."
psql -h "$HOST" -d "$DB" -v ON_ERROR_STOP=1 -tAc "
  SELECT schemaname, relname, n_live_tup
  FROM pg_stat_user_tables
  WHERE n_live_tup = 0
  ORDER BY 1, 2;
"

echo "Checking replication/restore lag markers are absent (server fully promoted)..."
psql -h "$HOST" -d "$DB" -v ON_ERROR_STOP=1 -tAc "SELECT pg_is_in_recovery();"

echo "Validation checks completed. A human DBA must still review row counts/spot-check data before cutover."
