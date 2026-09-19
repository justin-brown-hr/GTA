#!/usr/bin/env bash
#
# Unpack the client's asset drop into server-data/resources/[stream]/ as
# properly named FiveM resources ([stream] is where the live server keeps them).
#
# Why this is not a one-liner:
#   * 56 of the 75 archives are .rar and most use RAR5, which p7zip cannot
#     decompress. The previous version of this script used 7z and silently
#     installed only the .zip packs.
#   * A pack's resource folder is rarely named after the pack. Two different
#     vehicle packs both ship a folder literally called "fivem", and one weapon
#     pack's folder has a space in it — neither works as a FiveM resource name.
#   * Many packs are singleplayer add-ons (dlc.rpf / .oiv) with no FiveM
#     resource in them at all. Those are reported, not installed.
#
# Requires: unrar   (sudo apt-get install -y unrar)
#
# It has to be unrar specifically. In testing, 'unar' silently dropped 2 of the
# 10 files in anarchy_limeys.rar — including the main .ydr model — while
# reporting only a soft failure. unrar tests that same archive as clean and
# extracts it whole. A half-extracted MLO installs fine and then looks broken
# in game with nothing in the logs to explain it.
#
# .zip and .7z are handled by p7zip, which is fast and already installed.
#
# Full catalogue of what is in each pack: docs/client-assets.md
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Default: the repo's Files/ folder. The client also uploads straight to the
# VPS home directory, so allow pointing at that instead:
#   bash scripts/unpack-client-files.sh /root
SRC="${1:-$ROOT/Files}"
DEST="${HC_ASSET_DEST:-$ROOT/server-data/resources/[stream]}"
REPORT="$ROOT/docs/unpack-report.txt"
TMP=""  # created next to DEST below, so moves are renames, not copies
trap 'rm -rf "$TMP"' EXIT

HAVE_UNRAR=0; HAVE_UNAR=0
command -v unrar >/dev/null 2>&1 && HAVE_UNRAR=1
command -v unar  >/dev/null 2>&1 && HAVE_UNAR=1

if [[ $HAVE_UNRAR -eq 0 ]]; then
  echo "ERROR: 'unrar' not found. 56 of the packs are .rar, most of them RAR5,"
  echo "which p7zip cannot decompress at all."
  echo
  echo "  sudo apt-get update && sudo apt-get install -y unrar"
  echo
  if [[ $HAVE_UNAR -eq 1 ]]; then
    echo "'unar' is installed, but it dropped files from a known-good pack in"
    echo "testing and produced a broken MLO. To use it anyway, re-run with:"
    echo "  ALLOW_UNAR=1 $0"
    echo
  fi
  if [[ "${ALLOW_UNAR:-0}" != "1" || $HAVE_UNAR -eq 0 ]]; then
    exit 1
  fi
  echo "WARNING: falling back to 'unar'. Verify every installed resource by hand."
fi

# Extract one archive into a directory, using the fastest tool that can read it.
extract() {
  local archive="$1" dest="$2" ext="${1##*.}"
  case "${ext,,}" in
    zip|7z|oiv)
      7z x -y -o"$dest" "$archive" >/dev/null 2>&1
      ;;
    *)
      if [[ $HAVE_UNRAR -eq 1 ]]; then
        # -t first: refuse to install anything out of a damaged archive.
        unrar t -inul "$archive" >/dev/null 2>&1 || return 1
        unrar x -inul -o+ "$archive" "$dest/" >/dev/null 2>&1
      else
        unar -q -f -o "$dest" "$archive" >/dev/null 2>&1
      fi
      ;;
  esac
}

[[ -d "$SRC" ]] || { echo "No archive folder at $SRC"; exit 1; }
mkdir -p "$DEST"
# Repo root: same filesystem as DEST (so mv is a rename) but outside the
# resources tree, where FXServer would scan it.
TMP="$(mktemp -d "$ROOT/.unpack-XXXXXX")"

# Canonical resource names. Key = start of the archive filename.
# Anything not listed here is installed under a sanitised version of its own
# folder name, which is fine for the anarchy_* MLOs.
# Packs that ship more than one resource are named by their inner folder;
# this maps those folders to the names server.cfg expects.
declare -A RENAME_LEAF=(
  [mitsuriswitchdrum]=hc_wep_mitsuri
  [tanjiroswitchdrum]=hc_wep_tanjiro
)

declare -A RENAME=(
  [09a3e1-CyberTruck]=hc_veh_cybertruck
  [227375-MRJ_CometMans]=hc_veh_cometmans
  [d01734-sddriftvet]=hc_veh_sddriftvet
  [31fb42-s1000rr23]=hc_veh_s1000rr23
  [4607bc-UDM-DOMA]=hc_wep_doma
  [8d1a5a-revenant_15]=hc_wep_revenant15
  [c6e70f-police_ghostv2]=hc_wep_ghost
  [ba3c50-pringlesmg]=hc_wep_pringle
  [b091e9-FiveSeven]=hc_wep_fiveseven
)

# Keep the original case: FiveM names are case-sensitive on Linux, and
# lowercasing would install e.g. anarchy_Island a second time as anarchy_island
# (two resources streaming the same map) instead of detecting it already exists.
sanitise() {
  echo "$1" | tr ' ' '_' | tr -cd 'A-Za-z0-9_-'
}

installed=0; converted=0; skipped=0
: > "$REPORT"
{
  echo "Heartless City — asset unpack report"
  echo "Generated $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo
} >> "$REPORT"

shopt -s nullglob nocaseglob
for archive in "$SRC"/*.{zip,rar,7z}; do
  [[ -f "$archive" ]] || continue
  base="$(basename "$archive")"
  stem="${base%.*}"
  work="$TMP/$(sanitise "$stem")"
  rm -rf "$work"; mkdir -p "$work"

  echo "[......] $base"
  if ! extract "$archive" "$work"; then
    echo "[FAIL  ] $base — could not extract" | tee -a "$REPORT"
    skipped=$((skipped + 1))
    rm -rf "$work"
    continue
  fi

  # Some packs ship archives inside archives (e.g. the Demon Slayer glocks).
  while IFS= read -r -d '' inner; do
    extract "$inner" "$(dirname "$inner")" || true
    rm -f "$inner"
  done < <(find "$work" \( -iname '*.rar' -o -iname '*.zip' -o -iname '*.7z' -o -iname '*.oiv' \) -print0)

  # A FiveM resource is any directory containing a manifest.
  mapfile -t manifests < <(find "$work" \( -iname 'fxmanifest.lua' -o -iname '__resource.lua' \) -printf '%h\n' | sort -u)

  if [[ ${#manifests[@]} -eq 0 ]]; then
    if find "$work" -iname 'dlc.rpf' -o -iname '*.oiv' | grep -q .; then
      echo "[CONVERT] $base — singleplayer add-on (dlc.rpf/.oiv), needs conversion before use" >> "$REPORT"
      converted=$((converted + 1))
    else
      echo "[SKIP  ] $base — no FiveM resource and no dlc.rpf found" >> "$REPORT"
      skipped=$((skipped + 1))
    fi
    rm -rf "$work"
    continue
  fi

  for mdir in "${manifests[@]}"; do
    # Nested manifests (a resource inside a resource) — keep only the outermost.
    parent="$(dirname "$mdir")"
    if [[ -f "$parent/fxmanifest.lua" || -f "$parent/__resource.lua" ]]; then
      continue
    fi

    leaf="$(sanitise "$(basename "$mdir")")"
    name="${RENAME_LEAF[${leaf,,}]:-}"

    # A single-resource pack takes its canonical name from the archive.
    if [[ -z "$name" && ${#manifests[@]} -eq 1 ]]; then
      for key in "${!RENAME[@]}"; do
        if [[ "$stem" == "$key"* ]]; then name="${RENAME[$key]}"; break; fi
      done
    fi

    if [[ -z "$name" ]]; then
      name="$leaf"
      # "fivem" and friends are not usable resource names — two different packs
      # both ship a folder called exactly that.
      if [[ "${name,,}" == "fivem" || "${name,,}" == "resource"* || -z "$name" ]]; then
        name="$(sanitise "$stem")"
        [[ ${#manifests[@]} -gt 1 ]] && name="${name}_${leaf}"
      fi
    fi

    out="$DEST/$name"
    if [[ -d "$out" ]]; then
      echo "[EXISTS] $name  (from $base)" | tee -a "$REPORT"
      continue
    fi
    # mv, not cp: the work dir is disposable, and on the same filesystem a move
    # is instant and does not double the disk usage of a 10+ GB clothing pack.
    mv "$mdir" "$out" 2>/dev/null || { mkdir -p "$out" && cp -a "$mdir/." "$out/"; }
    echo "[OK    ] $name  <- $base" | tee -a "$REPORT"
    installed=$((installed + 1))
  done
  rm -rf "$work"
done

{
  echo
  echo "Installed as resources : $installed"
  echo "Need conversion (SP)   : $converted"
  echo "Skipped / failed       : $skipped"
  echo
  echo "Add an 'ensure <name>' line to server.cfg for each [OK] resource above."
  echo "Do NOT use 'ensure [assets]' — a flat ensure of everything has broken"
  echo "joins on this server before."
} >> "$REPORT"

echo
echo "Installed $installed resource(s); $converted pack(s) need conversion; $skipped skipped."
echo "Full report: $REPORT"
