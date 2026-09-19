#!/usr/bin/env bash
# Heartless City RP — database backup.
#
# The whole player economy (characters, money, vehicles, businesses) lives in
# MySQL. Until this runs on a schedule, one disk failure or one bad SQL import
# ends the server.
#
# Manual run (on the VPS, as root — socket auth, no password needed):
#   sudo bash scripts/backup-db.sh
#
# On the VPS it runs nightly from the systemd timer heartless-db-backup.timer
# (see docs/vps-ubuntu.md). Check it with:
#   systemctl list-timers heartless-db-backup.timer
#   journalctl -u heartless-db-backup --since today
set -euo pipefail

DB_NAME="${DB_NAME:-heartless_city}"
DB_USER="${DB_USER:-root}"
DB_PASSWORD="${MYSQL_PASSWORD:-}"
# Leave DB_HOST unset to use the local socket. On the VPS, MariaDB's root
# account authenticates by socket with no password, which TCP (127.0.0.1)
# does not allow.
DB_HOST="${DB_HOST:-}"
BACKUP_DIR="${BACKUP_DIR:-/opt/heartless/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"

stamp="$(date +%Y-%m-%d_%H%M)"
target="$BACKUP_DIR/${DB_NAME}_${stamp}.sql.gz"

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

echo "[backup] dumping $DB_NAME -> $target"

# Dump to a .partial file and only rename it once it is verified. With
# `set -e`, a failed mysqldump would otherwise exit before any check runs and
# leave a broken file behind that looks like the newest backup.
partial="$target.partial"
# --single-transaction keeps InnoDB consistent without locking players out.
if ! mysqldump \
  ${DB_HOST:+--host="$DB_HOST"} \
  --user="$DB_USER" \
  ${DB_PASSWORD:+--password="$DB_PASSWORD"} \
  --single-transaction \
  --quick \
  --routines \
  --events \
  "$DB_NAME" | gzip -9 > "$partial"; then
  echo "[backup] FAILED: mysqldump did not complete" >&2
  rm -f "$partial"
  exit 1
fi

# A dump that gzip cannot read, or that has no tables in it, is not a backup.
if ! gzip -t "$partial" || ! zcat "$partial" | grep -q "^CREATE TABLE"; then
  echo "[backup] FAILED: $partial is corrupt or empty" >&2
  rm -f "$partial"
  exit 1
fi

mv "$partial" "$target"
tables=$(zcat "$target" | grep -c "^CREATE TABLE")
echo "[backup] ok ($(du -h "$target" | cut -f1), $tables tables)"

echo "[backup] pruning dumps older than $KEEP_DAYS days"
find "$BACKUP_DIR" -name "${DB_NAME}_*.sql.gz" -mtime "+$KEEP_DAYS" -print -delete
# Leftovers from a run that was killed mid-dump.
find "$BACKUP_DIR" -name "*.partial" -mmin +60 -print -delete

echo "[backup] restore with:"
echo "  gunzip -c $target | mysql $DB_NAME"
echo
echo "[backup] REMINDER: copy these off the VPS (scp / object storage)."
echo "         A backup that only exists on the box that dies is not a backup."
