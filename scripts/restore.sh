#!/usr/bin/env sh
set -eu

if [ $# -ne 1 ]; then
  echo "Usage: restore.sh /path/to/backup.sql.gz"
  exit 1
fi

BACKUP_FILE=$1

gunzip -c "$BACKUP_FILE" | docker exec -i postgres_db psql -U appuser appdb

echo "Restore completed"
