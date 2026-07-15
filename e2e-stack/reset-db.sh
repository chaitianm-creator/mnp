#!/usr/bin/env bash
# E2E用DBの初期化 (supabase db reset 相当)
# 使い方: PGURL_SUPER="postgresql://postgres@127.0.0.1:55432/postgres" ./e2e-stack/reset-db.sh
set -euo pipefail
cd "$(dirname "$0")/.."

PGURL_SUPER="${PGURL_SUPER:-postgresql://postgres@127.0.0.1:55432/postgres}"
DB_NAME="${DB_NAME:-mokutomo}"
PGURL_DB="${PGURL_SUPER%/*}/$DB_NAME"

psql "$PGURL_SUPER" -v ON_ERROR_STOP=1 -q \
  -c "drop database if exists $DB_NAME;" \
  -c "create database $DB_NAME;"

for f in e2e-stack/shim.sql supabase/migrations/*.sql supabase/seed.sql; do
  echo "applying: $f"
  psql "$PGURL_DB" -v ON_ERROR_STOP=1 -q -f "$f"
done
echo "DB reset complete: $PGURL_DB"
