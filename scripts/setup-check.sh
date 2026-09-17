#!/usr/bin/env bash
# Heartless City RP — checklist for Phase 0 setup
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
echo "== Heartless City RP setup check =="
echo "Repo: $ROOT"

need() {
  if [[ -e "$1" ]]; then echo "[OK] $1"; else echo "[MISSING] $1"; fi
}

need "$ROOT/server-data/server.cfg.example"
need "$ROOT/database/schema.sql"
need "$ROOT/server-data/resources/[heartless]/hc-core/fxmanifest.lua"
need "$ROOT/docs/roadmap.md"

if [[ ! -f "$ROOT/server-data/server.cfg" ]]; then
  echo ""
  echo "Next: cp server-data/server.cfg.example server-data/server.cfg"
  echo "Then fill sv_licenseKey + mysql_connection_string"
fi

echo ""
echo "Install qb-core, oxmysql, ox_lib, ox_inventory, ox_target, pma-voice into resources/"
echo "Import database/schema.sql after QB base SQL"
echo "Merge database/ox_items_heartless.lua into ox_inventory items"
echo "See docs/dependencies.md and docs/roadmap.md"
