#!/usr/bin/env bash
# Runtime fixes after first bootstrap (run on VPS as root)
set -euo pipefail

UNIT=/etc/systemd/system/heartless-fx.service
sed -i 's|WorkingDirectory=/opt/heartless/fxserver|WorkingDirectory=/opt/heartless/GTA/server-data|' "$UNIT"
systemctl daemon-reload

RES='/opt/heartless/GTA/server-data/resources/[standalone]/oxmysql'
if [[ ! -f "$RES/dist/build.js" && ! -f "$RES/dist/build.js" ]]; then
  rm -rf /tmp/oxmysql-extract "$RES"
  curl -fsSL -o /tmp/oxmysql.zip https://github.com/overextended/oxmysql/releases/latest/download/oxmysql.zip
  mkdir -p /tmp/oxmysql-extract
  unzip -qo /tmp/oxmysql.zip -d /tmp/oxmysql-extract
  mkdir -p '/opt/heartless/GTA/server-data/resources/[standalone]'
  if [[ -d /tmp/oxmysql-extract/oxmysql ]]; then
    mv /tmp/oxmysql-extract/oxmysql "$RES"
  else
    mkdir -p "$RES"
    mv /tmp/oxmysql-extract/* "$RES/"
  fi
fi

CFG=/opt/heartless/GTA/server-data/server.cfg
if ! grep -q 'ensure qb-multicharacter' "$CFG"; then
  cat >> "$CFG" <<'QB'

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
QB
fi

if [[ -f /root/fivem.key ]]; then
  KEY="$(tr -d ' \n' </root/fivem.key)"
  sed -i "s|sv_licenseKey \".*\"|sv_licenseKey \"${KEY}\"|" "$CFG"
fi

# Merge Heartless items into ox_inventory if present
ITEMS='/opt/heartless/GTA/server-data/resources/[standalone]/ox_inventory/data/items.lua'
EXTRA=/opt/heartless/GTA/database/ox_items_heartless.lua
if [[ -f "$ITEMS" && -f "$EXTRA" ]] && ! grep -q "hh_leaf" "$ITEMS"; then
  python3 - <<'PY'
from pathlib import Path
items = Path("/opt/heartless/GTA/server-data/resources/[standalone]/ox_inventory/data/items.lua")
extra = Path("/opt/heartless/GTA/database/ox_items_heartless.lua").read_text()
# extra is "return { ... }" — take inner entries
start = extra.find("{")
end = extra.rfind("}")
body = extra[start+1:end].strip().rstrip(",")
text = items.read_text()
# insert before final closing brace of return table
idx = text.rfind("}")
if idx == -1:
    raise SystemExit("items.lua parse fail")
items.write_text(text[:idx] + "\n    -- Heartless City\n    " + body + "\n" + text[idx:])
print("items merged")
PY
fi

echo FIX_OK
