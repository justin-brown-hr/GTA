#!/usr/bin/env bash
# Heartless City RP — Ubuntu VPS bootstrap (run on the VPS as root).
# See docs/vps-ubuntu.md
set -euo pipefail

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FX_DIR="${FX_DIR:-/opt/heartless/fxserver}"
DATA_DIR="${DATA_DIR:-$REPO_ROOT/server-data}"
MYSQL_DB="${MYSQL_DB:-heartless_city}"
MYSQL_USER="${MYSQL_USER:-heartless}"
MYSQL_PASSWORD="${MYSQL_PASSWORD:-}"
FIVEM_LICENSE_KEY="${FIVEM_LICENSE_KEY:-}"
SECRET_FILE="/root/heartless-runtime.env"

export DEBIAN_FRONTEND=noninteractive

echo "== Packages =="
apt-get update -y
apt-get install -y git curl wget xz-utils ca-certificates mariadb-server ufw \
  screen unzip tar file lsof p7zip-full

echo "== Firewall (SSH + FiveM) =="
ufw allow OpenSSH || ufw allow 22/tcp
ufw allow 30120/tcp
ufw allow 30120/udp
ufw --force enable || true

echo "== MariaDB =="
systemctl enable --now mariadb
if [[ -z "$MYSQL_PASSWORD" ]]; then
  if [[ -f "$SECRET_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$SECRET_FILE"
  fi
fi
if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
  MYSQL_PASSWORD="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
fi

mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_DB}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
ALTER USER '${MYSQL_USER}'@'localhost' IDENTIFIED BY '${MYSQL_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DB}\`.* TO '${MYSQL_USER}'@'localhost';
FLUSH PRIVILEGES;
SQL

umask 077
cat > "$SECRET_FILE" <<EOF
MYSQL_DB=${MYSQL_DB}
MYSQL_USER=${MYSQL_USER}
MYSQL_PASSWORD=${MYSQL_PASSWORD}
FIVEM_LICENSE_KEY=${FIVEM_LICENSE_KEY}
EOF
chmod 600 "$SECRET_FILE"

echo "== FXServer artifacts =="
mkdir -p "$FX_DIR"
if [[ ! -x "$FX_DIR/run.sh" ]]; then
  BASE="https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/"
  URL="$(curl -fsSL 'https://changelogs-live.fivem.net/api/changelog/versions/linux/server' | grep -oE '"recommended_download"[[:space:]]*:[[:space:]]*"[^"]+"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)"
  if [[ -z "$URL" || "$URL" != https://* ]]; then
    HTML="$(mktemp)"
    curl -fsSL "$BASE" > "$HTML"
    REL="$(awk -F'"' '/LATEST RECOMMENDED/{print p} {p=$2}' "$HTML" | head -1)"
    rm -f "$HTML"
    URL="${BASE}${REL}"
  fi
  echo "Downloading $URL"
  curl -fL "$URL" -o /tmp/fx.tar.xz
  file /tmp/fx.tar.xz | grep -qi 'xz compressed' || { echo "Artifact download is not xz"; exit 1; }
  tar -xJf /tmp/fx.tar.xz -C "$FX_DIR"
  rm -f /tmp/fx.tar.xz
fi

echo "== Resource stack =="
bash "$REPO_ROOT/scripts/clone-stack.sh" "$DATA_DIR/resources"

echo "== Import SQL =="
# qb-core player tables (filename varies by version)
QB_SQL="$(find "$DATA_DIR/resources/[qb]/qb-core" -maxdepth 2 -iname '*.sql' | head -1 || true)"
if [[ -n "${QB_SQL}" ]]; then
  echo "Importing $QB_SQL"
  mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" < "$QB_SQL" || true
fi
OX_SQL="$(find "$DATA_DIR/resources/[standalone]/ox_inventory" -iname '*.sql' | head -1 || true)"
if [[ -n "${OX_SQL}" ]]; then
  echo "Importing $OX_SQL"
  mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" < "$OX_SQL" || true
fi
mysql -u "$MYSQL_USER" -p"$MYSQL_PASSWORD" "$MYSQL_DB" < "$REPO_ROOT/database/schema.sql"

echo "== server.cfg =="
if [[ ! -f "$DATA_DIR/server.cfg" ]]; then
  cp "$DATA_DIR/server.cfg.example" "$DATA_DIR/server.cfg"
fi
if [[ -n "$FIVEM_LICENSE_KEY" ]]; then
  sed -i "s|sv_licenseKey \".*\"|sv_licenseKey \"${FIVEM_LICENSE_KEY}\"|" "$DATA_DIR/server.cfg"
fi
CONN="mysql://${MYSQL_USER}:${MYSQL_PASSWORD}@127.0.0.1/${MYSQL_DB}?charset=utf8mb4"
# escape & for sed
ESC="${CONN//&/\\&}"
sed -i "s|set mysql_connection_string \".*\"|set mysql_connection_string \"${ESC}\"|" "$DATA_DIR/server.cfg"

# Ensure core CFX + ox inventory framework if missing
if ! grep -q 'ensure mapmanager' "$DATA_DIR/server.cfg"; then
  cat >> "$DATA_DIR/server.cfg" <<'CFG'

## Default CFX
ensure mapmanager
ensure chat
ensure spawnmanager
ensure sessionmanager
ensure hardcap
ensure baseevents
CFG
fi
if ! grep -q 'inventory:framework' "$DATA_DIR/server.cfg"; then
  cat >> "$DATA_DIR/server.cfg" <<'CFG'

setr inventory:framework "qb"
setr voicer:enableUi 0
CFG
fi
if ! grep -q 'ensure qb-multicharacter' "$DATA_DIR/server.cfg"; then
  cat >> "$DATA_DIR/server.cfg" <<'CFG'

ensure qb-multicharacter
ensure qb-spawn
ensure qb-apartments
ensure qb-clothing
ensure qb-weathersync
ensure qb-hud
ensure qb-smallresources
ensure qb-banking
ensure qb-management
ensure qb-vehiclekeys
ensure qb-garages
ensure qb-menu
ensure qb-input
ensure qb-loading
ensure qb-interior
ensure qb-doorlock
ensure qb-shops
ensure qb-weapons
ensure qb-fuel
ensure qb-adminmenu
ensure qb-scoreboard
ensure qb-radialmenu
ensure qb-ambulancejob
ensure qb-policejob
ensure pma-voice
CFG
fi

echo "== systemd =="
cat > /etc/systemd/system/heartless-fx.service <<EOF
[Unit]
Description=Heartless City RP FXServer
After=network-online.target mariadb.service
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=${FX_DIR}
ExecStart=${FX_DIR}/run.sh +exec ${DATA_DIR}/server.cfg
Restart=on-failure
RestartSec=8
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable heartless-fx
systemctl restart heartless-fx

echo ""
echo "Install complete."
echo "Secrets file: $SECRET_FILE"
echo "Join: connect $(curl -fsS ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}'):30120"
echo "Logs: journalctl -u heartless-fx -f"
echo "Merge database/ox_items_heartless.lua into ox_inventory/data/items.lua if not already merged."
