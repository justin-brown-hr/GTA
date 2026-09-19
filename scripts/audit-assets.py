#!/usr/bin/env python3
"""
Heartless City — asset audit.

Opens every archive in a folder and reports what each pack ACTUALLY contains,
read from the pack's own files rather than guessed from its name:

  * FiveM-ready resources (folders with a manifest) vs singleplayer add-ons
  * vehicle spawn names (vehicles.meta, including inside sealed dlc.rpf files)
  * addon weapons (weapons.meta) and which vanilla weapons a skin pack replaces
  * clothing: drawables per slot, male/female, whether the shop metadata exists
  * ped models (peds.meta)
  * escrow-locked assets (.fxap) that need a Keymaster entitlement
  * damaged archives and split (multi-volume) sets

READ-ONLY. Source archives are never modified or moved. Each archive is
extracted into a temporary folder, inspected, and the folder is deleted.

Usage (on the VPS):
    sudo apt-get install -y unrar          # once — p7zip cannot read RAR5
    python3 scripts/audit-assets.py /root              > /tmp/asset-audit.md
    python3 scripts/audit-assets.py /root --only "Doogie,veefemales,Raheem"

Standard library only; needs python3, unrar and 7z on PATH.
"""
import argparse
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import zlib
from collections import defaultdict

ARCHIVE_EXT = ('.zip', '.rar', '.7z', '.oiv')

# ---------------------------------------------------------------------------
# RPF7 — GTA V's archive format. Singleplayer add-ons hide vehicles.meta in
# here. Only the unencrypted ("OPEN") variant is readable without game keys,
# which covers most community add-ons.
# ---------------------------------------------------------------------------
RPF_OPEN = 0x4E45504F


def rpf_metas(path):
    """Return {inner_path: bytes} for .meta files in an RPF, or None if encrypted."""
    with open(path, 'rb') as f:
        head = f.read(16)
        if len(head) < 16 or head[:4] != b'7FPR':
            return {}
        count, names_len, enc = struct.unpack('<III', head[4:16])
        if enc != RPF_OPEN:
            return None
        table = f.read(count * 16)
        names = f.read(names_len)

        def name_at(off):
            end = names.find(b'\0', off)
            return names[off:end].decode('utf-8', 'replace')

        def entry(i):
            b = table[i * 16:(i + 1) * 16]
            name = name_at(struct.unpack('<H', b[0:2])[0])
            if struct.unpack('<I', b[4:8])[0] == 0x7FFFFF00:
                idx, cnt = struct.unpack('<II', b[8:16])
                return name, True, idx, cnt, 0, 0
            size = b[2] | (b[3] << 8) | (b[4] << 16)
            offset = (b[5] | (b[6] << 8) | (b[7] << 16)) * 512
            usize = struct.unpack('<I', b[8:12])[0]
            return name, False, offset, size, usize, 0

        out = {}

        def walk(i, prefix, depth=0):
            if depth > 32 or not (0 <= i < count):
                return
            name, is_dir, a, b, c, _ = entry(i)
            if is_dir:
                base = prefix + name + '/' if name else prefix
                for j in range(a, a + b):
                    walk(j, base, depth + 1)
            elif name.lower().endswith('.meta'):
                offset, size, usize = a, b, c
                f.seek(offset)
                raw = f.read(size or usize)
                if size and size != usize:
                    try:
                        raw = zlib.decompressobj(-15).decompress(raw)
                    except zlib.error:
                        pass
                out[prefix + name] = raw

        walk(0, '')
        return out


# ---------------------------------------------------------------------------
# Extraction
# ---------------------------------------------------------------------------
def have(tool):
    return shutil.which(tool) is not None


def test_archive(path):
    """True = archive is intact, False = damaged, None = could not test."""
    low = path.lower()
    if low.endswith('.rar') and have('unrar'):
        return subprocess.run(['unrar', 't', '-inul', path],
                              capture_output=True).returncode == 0
    if have('7z') and not low.endswith('.rar'):
        return subprocess.run(['7z', 't', path],
                              capture_output=True).returncode == 0
    return None


def is_volume(path):
    """A split RAR set member ("part1.rar" etc.) cannot be read on its own."""
    if not path.lower().endswith('.rar') or not have('unrar'):
        return False
    r = subprocess.run(['unrar', 'lt', path], capture_output=True, text=True, errors='replace')
    return 'volume' in r.stdout.lower() and 'part' in r.stdout.lower()


def list_archive(path):
    """Every path inside the archive, without extracting anything."""
    low = path.lower()
    if low.endswith('.rar') and have('unrar'):
        r = subprocess.run(['unrar', 'lb', path], capture_output=True, text=True, errors='replace')
        return [l.strip().replace('\\', '/') for l in r.stdout.splitlines() if l.strip()]
    r = subprocess.run(['7z', 'l', '-slt', '-ba', path], capture_output=True, text=True, errors='replace')
    return [l[7:].strip().replace('\\', '/') for l in r.stdout.splitlines() if l.startswith('Path = ')]


# Only these are needed to identify a pack. Models and textures are the bulk of
# every archive (30+ GB for some clothing packs) and are judged by name alone.
METADATA_MASKS = ['*.meta', '*.ymt', 'fxmanifest.lua', '__resource.lua', '*.fxap']
# Archives inside archives and sealed .rpf files are only opened on packs small
# enough that extracting them is cheap.
DEEP_MASKS = ['*.rpf', '*.zip', '*.rar', '*.7z', '*.oiv']
DEEP_LIMIT = 2 * 1024 ** 3


def extract(path, dest, masks=None):
    """Extract an archive, or only the files matching `masks` if given."""
    low = path.lower()
    masks = masks or []
    if low.endswith('.rar'):
        if have('unrar'):
            cmd = ['unrar', 'x', '-inul', '-o+'] + (['-r'] if masks else []) + [path] + masks + [dest + '/']
        elif have('unar'):
            cmd = ['unar', '-q', '-f', '-o', dest, path]
        else:
            return False
    else:
        cmd = ['7z', 'x', '-y', '-o' + dest, path] + (['-r'] + masks if masks else [])
    return subprocess.run(cmd, capture_output=True).returncode == 0


def extract_nested(root):
    """Some packs ship archives inside archives — open one level deeper."""
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            if fn.lower().endswith(ARCHIVE_EXT):
                inner = os.path.join(dirpath, fn)
                target = os.path.join(dirpath, '_' + re.sub(r'\W+', '_', fn))
                os.makedirs(target, exist_ok=True)
                extract(inner, target)


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------
MODEL_RE = re.compile(rb'<modelName>\s*([A-Za-z0-9_]+)', re.I)
WEAPON_RE = re.compile(rb'<Name>\s*(WEAPON_[A-Za-z0-9_]+)', re.I)
PED_RE = re.compile(rb'<Name>\s*([A-Za-z0-9_]+)\s*</Name>', re.I)

# Vanilla weapon model prefixes -> the weapon a replace pack re-skins.
REPLACE = [
    ('w_pi_appistol', 'WEAPON_APPISTOL'), ('w_pi_combatpistol', 'WEAPON_COMBATPISTOL'),
    ('w_pi_pistol50', 'WEAPON_PISTOL50'), ('w_pi_heavypistol', 'WEAPON_HEAVYPISTOL'),
    ('w_pi_sns_pistol', 'WEAPON_SNSPISTOL'), ('w_pi_pistol', 'WEAPON_PISTOL'),
    ('w_sb_microsmg', 'WEAPON_MICROSMG'), ('w_sb_minismg', 'WEAPON_MINISMG'),
    ('w_sb_assaultsmg', 'WEAPON_ASSAULTSMG'), ('w_sb_smg', 'WEAPON_SMG'),
    ('w_ar_specialcarbine', 'WEAPON_SPECIALCARBINE'), ('w_ar_carbinerifle', 'WEAPON_CARBINERIFLE'),
    ('w_ar_assaultrifle', 'WEAPON_ASSAULTRIFLE'), ('w_sg_heavyshotgun', 'WEAPON_HEAVYSHOTGUN'),
    ('w_sg_pumpshotgun', 'WEAPON_PUMPSHOTGUN'),
]

# Freemode clothing component slots, as they appear in drawable file names.
SLOTS = {
    'head': 'faces', 'berd': 'masks', 'hair': 'hair', 'uppr': 'arms/torso',
    'lowr': 'legs', 'hand': 'bags/parachutes', 'feet': 'shoes', 'teef': 'accessories (neck)',
    'accs': 'undershirts', 'task': 'vests/armour', 'decl': 'decals', 'jbib': 'tops',
    'p_head': 'hats', 'p_eyes': 'glasses', 'p_ears': 'earrings',
    'p_lwrist': 'watches', 'p_rwrist': 'bracelets',
}
DRAWABLE_RE = re.compile(r'(?:^|[\^/_])(p_head|p_eyes|p_ears|p_lwrist|p_rwrist|'
                         r'head|berd|hair|uppr|lowr|hand|feet|teef|accs|task|decl|jbib)_(\d{3})',
                         re.I)


def gender_of(path):
    p = path.lower()
    if 'mp_f_freemode' in p or 'female' in p or '[f]' in p or '/f/' in p:
        return 'female'
    if 'mp_m_freemode' in p or 'male' in p or '[m]' in p or '/m/' in p:
        return 'male'
    return 'unknown'


def analyse(root, listing=()):
    """
    `listing` = every path in the archive (name-based checks: clothing slots,
    weapon skins, stream counts). `root` = the small metadata files that were
    actually extracted (content-based checks: spawn names, escrow, peds).
    """
    r = {
        'resources': set(), 'models': set(), 'addon_weapons': set(), 'replaces': set(),
        'peds': set(), 'clothing': defaultdict(lambda: defaultdict(set)),
        'clothing_meta': False, 'creature_ymt': 0, 'escrow': False,
        'dlc_rpf': False, 'encrypted_rpf': 0, 'streams': 0, 'files': 0,
    }

    def read_meta(name, data):
        base = os.path.basename(name).lower()
        if base == 'vehicles.meta':
            r['models'].update(m.decode() for m in MODEL_RE.findall(data))
        elif base in ('weapons.meta', 'weaponarchetypes.meta'):
            r['addon_weapons'].update(w.decode().upper() for w in WEAPON_RE.findall(data))
        elif base == 'peds.meta':
            r['peds'].update(p.decode() for p in PED_RE.findall(data))
        if 'shop_ped_apparel' in base or b'ShopPedApparel' in data[:4000]:
            r['clothing_meta'] = True

    # --- name-based: the full archive listing ---------------------------------
    for rel in listing:
        low = os.path.basename(rel).lower()
        if not low or '.' not in low:
            continue
        r['files'] += 1
        if low.endswith('.fxap'):
            r['escrow'] = True
        elif low.endswith('.ymt'):
            r['creature_ymt'] += 1
        elif low == 'dlc.rpf':
            r['dlc_rpf'] = True
        elif low in ('fxmanifest.lua', '__resource.lua'):
            r['resources'].add(os.path.basename(os.path.dirname(rel)) or '(archive root)')
        elif low.endswith(('.ydd', '.ytd', '.ydr', '.yft', '.ymap', '.ytyp', '.ybn')):
            r['streams'] += 1
            if low.endswith('.ydd'):
                m = DRAWABLE_RE.search(low)
                if m:
                    r['clothing'][gender_of(rel)][m.group(1).lower()].add(m.group(2))
            for pref, wep in REPLACE:
                if re.search(re.escape(pref) + r'[._+]', low):
                    r['replaces'].add(wep)
                    break

    # --- content-based: the extracted metadata --------------------------------
    for dirpath, _dirs, files in os.walk(root):
        for fn in files:
            low = fn.lower()
            full = os.path.join(dirpath, fn)
            rel = os.path.relpath(full, root)
            if not listing:
                r['files'] += 1
            if low in ('fxmanifest.lua', '__resource.lua'):
                r['resources'].add(os.path.basename(dirpath))
                try:
                    if 'escrow' in open(full, errors='replace').read().lower():
                        r['escrow'] = True
                except OSError:
                    pass
            elif low.endswith('.fxap'):
                r['escrow'] = True
            elif low.endswith('.meta'):
                try:
                    read_meta(fn, open(full, 'rb').read())
                except OSError:
                    pass
            elif low.endswith('.rpf'):
                if low == 'dlc.rpf':
                    r['dlc_rpf'] = True
                try:
                    found = rpf_metas(full)
                except Exception:
                    found = {}
                if found is None:
                    r['encrypted_rpf'] += 1
                else:
                    for name, data in found.items():
                        read_meta(name, data)
            elif listing:
                # Everything below was already counted from the archive listing.
                continue
            elif low.endswith('.ymt'):
                r['creature_ymt'] += 1
            elif low.endswith(('.ydd', '.ytd', '.ydr', '.yft', '.ymap', '.ytyp', '.ybn')):
                r['streams'] += 1
                if low.endswith('.ydd'):
                    m = DRAWABLE_RE.search(low)
                    if m:
                        r['clothing'][gender_of(rel)][m.group(1).lower()].add(m.group(2))
                for pref, wep in REPLACE:
                    if re.search(re.escape(pref) + r'[._+]', low):
                        r['replaces'].add(wep)
                        break
    return r


def classify(r):
    if r['escrow']:
        return 'ESCROW (Keymaster-locked)'
    if r['clothing']:
        return 'CLOTHING'
    if r['peds']:
        return 'PED MODELS'
    if r['models'] and not r['resources']:
        return 'VEHICLE (singleplayer — needs conversion)'
    if r['models']:
        return 'VEHICLE (FiveM-ready)'
    if r['addon_weapons']:
        return 'ADDON WEAPON'
    if r['replaces']:
        return 'WEAPON SKIN (replace)'
    if r['resources'] and r['streams']:
        return 'MLO / MAP'
    if r['resources']:
        return 'SCRIPT / LIBRARY'
    if r['dlc_rpf']:
        return 'SINGLEPLAYER ADD-ON (unidentified)'
    return 'UNKNOWN'


# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
def report(name, size, intact, volume, r, lines):
    kind = classify(r)
    lines.append(f"\n## {name}\n")
    lines.append(f"- **Type:** {kind}")
    lines.append(f"- **Size:** {size / 1048576:.1f} MB, {r['files']} files")
    if intact is False:
        lines.append("- **ARCHIVE DAMAGED** — `unrar t` / `7z t` failed. Ask the client to re-upload.")
    if volume:
        lines.append("- **Split archive** — part of a multi-volume set; every part must be present.")
    if r['resources']:
        lines.append(f"- **FiveM resource folder(s):** {', '.join(f'`{x}`' for x in sorted(r['resources']))}")
    if r['escrow']:
        lines.append("- **Escrow-protected** (`.fxap`). It only starts if this asset is granted to the "
                     "Keymaster account that owns the server's license key. Otherwise the console "
                     "shows 'You lack the required entitlement'.")
    if r['models']:
        lines.append(f"- **Vehicle spawn names:** {', '.join(f'`{x}`' for x in sorted(r['models']))}")
    if r['addon_weapons']:
        lines.append(f"- **Addon weapons:** {', '.join(f'`{x}`' for x in sorted(r['addon_weapons']))}")
    if r['replaces']:
        lines.append(f"- **Re-skins vanilla:** {', '.join(f'`{x}`' for x in sorted(r['replaces']))}")
    if r['peds']:
        lines.append(f"- **Ped models:** {', '.join(f'`{x}`' for x in sorted(r['peds']))}")
    if r['clothing']:
        lines.append(f"- **Shop metadata (`shop_ped_apparel`):** {'yes' if r['clothing_meta'] else 'NO — see note'}"
                     f" · creature `.ymt` files: {r['creature_ymt']}")
        lines.append("")
        lines.append("  | Ped | Slot | Drawables |")
        lines.append("  |-----|------|-----------|")
        for gender in sorted(r['clothing']):
            for slot, idx in sorted(r['clothing'][gender].items()):
                lines.append(f"  | {gender} | {SLOTS.get(slot, slot)} (`{slot}`) | {len(idx)} |")
    if r.get('note_big_rpf'):
        lines.append("- Pack is over 2 GB, so its sealed `dlc.rpf` was not opened — spawn names inside it are not listed.")
    if r['encrypted_rpf']:
        lines.append(f"- {r['encrypted_rpf']} encrypted `.rpf` — singleplayer contents not inspectable.")
    return kind


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('folder', help='folder holding the archives (e.g. /root)')
    ap.add_argument('--only', default='', help='comma-separated substrings; audit only matching archives')
    ap.add_argument('--no-test', action='store_true',
                    help='skip the full integrity test (it decompresses every byte — slow on 10 GB packs)')
    args = ap.parse_args()

    if not have('unrar'):
        print("WARNING: unrar not found — RAR5 archives cannot be read reliably. "
              "Install with: sudo apt-get install -y unrar", file=sys.stderr)

    wanted = [w.strip().lower() for w in args.only.split(',') if w.strip()]
    archives = sorted(
        f for f in os.listdir(args.folder)
        if f.lower().endswith(ARCHIVE_EXT) and os.path.isfile(os.path.join(args.folder, f))
        and (not wanted or any(w in f.lower() for w in wanted))
    )

    lines = ['# Asset audit', '', f'Folder: `{args.folder}` — {len(archives)} archive(s).']
    summary = []
    for i, name in enumerate(archives, 1):
        path = os.path.join(args.folder, name)
        print(f"[{i}/{len(archives)}] {name}", file=sys.stderr, flush=True)
        work = tempfile.mkdtemp(prefix='hc-audit-')
        try:
            intact = None if args.no_test else test_archive(path)
            volume = is_volume(path)
            listing = list_archive(path)
            small = os.path.getsize(path) <= DEEP_LIMIT
            extract(path, work, METADATA_MASKS + (DEEP_MASKS if small else []))
            if small:
                extract_nested(work)
                # Files that came out of archives-inside-archives are not in the
                # outer listing; add them so their clothing/skins get counted.
                for dirpath, _d, files in os.walk(work):
                    if os.sep + '_' in dirpath:
                        listing += [os.path.relpath(os.path.join(dirpath, f), work) for f in files]
            r = analyse(work, listing)
            if not small and not r['models'] and r['dlc_rpf']:
                r['note_big_rpf'] = True
        finally:
            shutil.rmtree(work, ignore_errors=True)
        kind = report(name, os.path.getsize(path), intact, volume, r, lines)
        summary.append((name, kind, intact))

    lines.insert(3, '\n| Archive | Type | Intact |\n|---------|------|--------|')
    for n, (name, kind, intact) in enumerate(summary):
        ok = {True: 'yes', False: '**NO**', None: '?'}[intact]
        lines.insert(4 + n, f'| {name} | {kind} | {ok} |')
    print('\n'.join(lines))


if __name__ == '__main__':
    main()
