#!/usr/bin/env sh
set -eu

TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_DIR=/backups
FILE=${BACKUP_DIR}/appdb_${TIMESTAMP}.sql.gz

mkdir -p "$BACKUP_DIR"

docker exec postgres_db pg_dump -U appuser appdb | gzip > "$FILE"

# Keep only the last 7 days of backups to avoid filling up the disk
find "$BACKUP_DIR" -name "appdb_*.sql.gz" -type f -mtime +7 -delete

echo "Backup written to $FILE"
