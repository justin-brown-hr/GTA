#!/usr/bin/env bash
# Heartless City RP — database backup.
#
# The whole player economy (characters, money, vehicles, businesses) lives in
# MySQL. Until this runs on a schedule, one disk failure or one bad SQL import
# ends the server.
#
# Manual run:
#   sudo MYSQL_PASSWORD='...' bash scripts/backup-db.sh
#
# Install as a nightly cron (03:30) on the VPS:
#   sudo crontab -e
#   30 3 * * * MYSQL_PASSWORD='...' /opt/heartless/GTA/scripts/backup-db.sh >> /var/log/heartless-backup.log 2>&1
set -euo pipefail

DB_NAME="${DB_NAME:-heartless_city}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${MYSQL_PASSWORD:-}"
DB_HOST="${DB_HOST:-127.0.0.1}"
BACKUP_DIR="${BACKUP_DIR:-/opt/heartless/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"

stamp="$(date +%Y-%m-%d_%H%M)"
target="$BACKUP_DIR/${DB_NAME}_${stamp}.sql.gz"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "[backup] dumping $DB_NAME -> $target"

# --single-transaction keeps InnoDB consistent without locking players out.
mysqldump \
  --host="$DB_HOST" \
  --user="$DB_USER" \
  ${DB_PASSWORD:+--password="$DB_PASSWORD"} \
  --single-transaction \
  --quick \
  --routines \
  --events \
  "$DB_NAME" | gzip -9 > "$target"

size=$(du -h "$target" | cut -f1)

# A dump that gzip cannot read is not a backup.
if ! gzip -t "$target"; then
  echo "[backup] FAILED: $target is corrupt" >&2
  rm -f "$target"
  exit 1
fi

echo "[backup] ok ($size)"

echo "[backup] pruning dumps older than $KEEP_DAYS days"
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime "+$KEEP_DAYS" -print -delete

echo "[backup] restore with:"
echo "  gunzip -c $target | mysql -u $DB_USER -p $DB_NAME"
echo
echo "[backup] REMINDER: copy these off the VPS (scp / object storage)."
echo "         A backup that only exists on the box that dies is not a backup."
