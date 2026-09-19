#!/usr/bin/env bash
# Clone ox + essential QB resources into server-data/resources (not vendored in git).
# Safe to re-run: skips directories that already exist.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
RES="${1:-$ROOT/server-data/resources}"

mkdir -p "$RES/[standalone]" "$RES/[qb]" "$RES/[voice]" "$RES/[cfx]"

clone() {
  local dest="$1"
  local url="$2"
  if [[ -d "$dest/.git" || -f "$dest/fxmanifest.lua" || -f "$dest/__resource.lua" ]]; then
    echo "[skip] $dest"
    return 0
  fi
  echo "[clone] $url -> $dest"
  git clone --depth 1 "$url" "$dest"
  sleep 1
}

echo "== Cloning stack into $RES =="

# Default CFX resources (chat, mapmanager, sessionmanager, spawnmanager, …)
if [[ ! -d "$RES/[cfx]/mapmanager" && ! -d "$RES/[cfx]/[managers]/mapmanager" ]]; then
  TMP="$(mktemp -d)"
  git clone --depth 1 https://github.com/citizenfx/cfx-server-data.git "$TMP/cfx-server-data"
  mkdir -p "$RES/[cfx]"
  cp -a "$TMP/cfx-server-data/resources/." "$RES/[cfx]/"
  rm -rf "$TMP"
else
  echo "[skip] $RES/[cfx]"
fi

clone "$RES/[standalone]/oxmysql"       https://github.com/overextended/oxmysql.git
clone "$RES/[standalone]/ox_lib"        https://github.com/overextended/ox_lib.git
clone "$RES/[standalone]/ox_inventory"  https://github.com/overextended/ox_inventory.git
clone "$RES/[standalone]/ox_target"     https://github.com/overextended/ox_target.git
clone "$RES/[voice]/pma-voice"          https://github.com/AvarianKnight/pma-voice.git
clone "$RES/[standalone]/PolyZone"      https://github.com/qbcore-framework/PolyZone.git
clone "$RES/[standalone]/interact-sound" https://github.com/qbcore-framework/interact-sound.git
clone "$RES/[standalone]/bob74_ipl"     https://github.com/qbcore-framework/bob74_ipl.git

# Joinable QB city (do NOT clone qb-inventory / qb-target — ox replaces them)
clone "$RES/[qb]/qb-core"            https://github.com/qbcore-framework/qb-core.git
clone "$RES/[qb]/qb-multicharacter"  https://github.com/qbcore-framework/qb-multicharacter.git
clone "$RES/[qb]/qb-spawn"           https://github.com/qbcore-framework/qb-spawn.git
clone "$RES/[qb]/qb-apartments"      https://github.com/qbcore-framework/qb-apartments.git
clone "$RES/[qb]/qb-clothing"        https://github.com/qbcore-framework/qb-clothing.git
clone "$RES/[qb]/qb-weathersync"     https://github.com/qbcore-framework/qb-weathersync.git
clone "$RES/[qb]/qb-hud"             https://github.com/qbcore-framework/qb-hud.git
clone "$RES/[qb]/qb-smallresources"  https://github.com/qbcore-framework/qb-smallresources.git
clone "$RES/[qb]/qb-banking"         https://github.com/qbcore-framework/qb-banking.git
clone "$RES/[qb]/qb-management"      https://github.com/qbcore-framework/qb-management.git
clone "$RES/[qb]/qb-vehiclekeys"     https://github.com/qbcore-framework/qb-vehiclekeys.git
clone "$RES/[qb]/qb-garages"         https://github.com/qbcore-framework/qb-garages.git
clone "$RES/[qb]/qb-menu"            https://github.com/qbcore-framework/qb-menu.git
clone "$RES/[qb]/qb-input"           https://github.com/qbcore-framework/qb-input.git
clone "$RES/[qb]/qb-loading"         https://github.com/qbcore-framework/qb-loading.git
clone "$RES/[qb]/qb-interior"        https://github.com/qbcore-framework/qb-interior.git
clone "$RES/[qb]/qb-doorlock"        https://github.com/qbcore-framework/qb-doorlock.git
clone "$RES/[qb]/qb-shops"           https://github.com/qbcore-framework/qb-shops.git
clone "$RES/[qb]/qb-weapons"         https://github.com/qbcore-framework/qb-weapons.git
clone "$RES/[qb]/qb-fuel"            https://github.com/qbcore-framework/qb-fuel.git
clone "$RES/[qb]/qb-adminmenu"       https://github.com/qbcore-framework/qb-adminmenu.git
clone "$RES/[qb]/qb-scoreboard"      https://github.com/qbcore-framework/qb-scoreboard.git
clone "$RES/[qb]/qb-radialmenu"      https://github.com/qbcore-framework/qb-radialmenu.git
clone "$RES/[qb]/qb-ambulancejob"    https://github.com/qbcore-framework/qb-ambulancejob.git
clone "$RES/[qb]/qb-policejob"       https://github.com/qbcore-framework/qb-policejob.git

echo ""
echo "Set ox_inventory framework to qb (convar inventory:framework qb)."
echo "Do not ensure qb-inventory or qb-target alongside ox_inventory / ox_target."
echo "Done."
