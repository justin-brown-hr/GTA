# Client asset drop — what is actually in `Files/`

**Audited 2026-09-18.** Every spawn name below was read out of the pack's own
`vehicles.meta` / `weapons.meta` — including the ones sealed inside `dlc.rpf`
and `.oiv` installers. These are confirmed, not guessed from folder names.

---

## 2026-09-19 upload (straight to the VPS, `/root`)

Audited with `scripts/audit-assets.py`, installed with
`scripts/unpack-client-files.sh /root`. All 13 archives tested intact.

| Pack | What it is | Status |
|------|-----------|--------|
| WSPDoogie Male V5 Pt1 + Pt2 | Men's clothing, 996 items (`wspdoogie-1`, `wspdoogie-2`) | **Live** |
| [veefemales] | Women's clothing, 3,812 items (`female-addon-1`, `veefemales4_01`–`07`) | **Live** |
| MaskedbyJas Skinpack + Raheem Skin | 9 replacement face skins, no two on the same face | **Live** as `hc_skins` |
| anarchy_NEWChicagoHood, ls_hills_house | New maps | **Live** |
| anarchy_BHV3 / BRHood / Block / VinewoodestateV3 / WaterPark | Maps from the first drop, now re-sent | **Live** |
| wais-jobpack | 20-job script pack (0resmon) | **Blocked** — see below |

Also installed from the first drop, because the deployed scripts now sell them:
`hc_veh_s1000rr23`, `hc_wep_pringle`, `hc_wep_mitsuri`, `hc_wep_tanjiro`,
`hc_wep_fiveseven`. `anarchy_HighClass` and `anarchy_MpHood2` are installed
but not enabled — the client did not re-send them.

### Skins — which face each one replaces

Pick that face in the character creator to get the skin.

| Male | | Female | |
|---|---|---|---|
| 001 | Justin | 007 | Sasha |
| 017 | Raheem | 008 | Asha |
| | | 009 | Kiani |
| | | 010 | Dalia |
| | | 011 | Leila |
| | | 012 | Olivia |
| | | 019 | Amber |

### The clothing is huge and unoptimised

- **31 GB**, out of 33 GB of stream assets on the whole server. FiveM sends
  streamed assets to every player, so **each new player downloads ~31 GB on
  first join**, and every one of those downloads is VPS bandwidth.
- On load, FiveM flagged **3,277 clothing assets over its 16 MB size warning**
  and **307 as oversized** ("can and WILL lead to streaming issues such as
  models not loading"). The worst is a single necklace at 172 MB.
- Before public launch, run the textures through an optimiser (grzyClothTool,
  which built these packs, has one). Halving texture resolution typically cuts
  size by ~75% with little visible difference in game.

### wais-jobpack will not start

1. **Escrow entitlement.** The server console says `You lack the required
   entitlement to use wais-jobpack` — the same error that blocks `5s_lib`. The
   license key in `server.cfg` belongs to a Keymaster account that does not own
   the client's purchases. **One fix unlocks both:** generate the server key
   from the Keymaster account that bought them (or transfer the assets to the
   account that owns the key).
2. **Game build.** Its manifest requires build **3258**; the server runs the
   default **1604** (`sv_enforceGameBuild` is not set).
3. It loads `@mysql-async`; this server runs `oxmysql`.
4. It overlaps `hc-jobs` — ask the client what they want it for.

---

## Read this first — three findings that change the plan

### 1. Most of the vehicle packs are not FiveM resources

Of 26 vehicle packs, **4 are FiveM-ready**. The other 22 are singleplayer
add-ons: a `dlc.rpf` (or an OpenIV `.oiv` installer) meant to be dropped into a
GTA V install with OpenIV. FiveM cannot stream those as-is.

Each one has to be unpacked and rebuilt as a resource — `stream/` folder plus a
`fxmanifest.lua` with `data_file 'VEHICLE_METADATA_FILE'` entries — before it
can go on the server. That is roughly 20–40 minutes per car with the right
tooling, i.e. **around two days of work for the 22**, and it is not scripting
work that the current milestones cover.

### 2. The unpack script cannot read most of these archives

[`scripts/unpack-client-files.sh`](../scripts/unpack-client-files.sh) used
`7z`, which does not support **RAR5** compression. 56 of the 75 archives are
`.rar`, and most are RAR5.

That is why exactly three exclusives are live on the VPS — `CyberTruckV`,
`cometmans`, `sddriftvet` — and all three came from `.zip` files. The rar packs
never extracted. The script has been rewritten to use `unrar` and to fail loudly
instead of silently skipping.

**Use `unrar`, not `unar`.** `unar` reads RAR5, but in testing it silently
dropped 2 of the 10 files in `anarchy_limeys.rar` — including the main `.ydr`
model — while reporting only a soft failure. `unrar` tests that same archive as
clean and extracts it whole. A half-extracted MLO installs without complaint and
then looks broken in game with nothing in the logs to explain it. The script now
refuses to run without `unrar` unless you set `ALLOW_UNAR=1`.

### 3. The weapon skins overwrite each other

Most weapon packs are **replace** skins: they re-texture a vanilla weapon rather
than adding a new one. Only one pack can own a given vanilla weapon slot, so
several of these cancel each other out — see section C.

---

## A. FiveM-ready — stream these today

| Pack | Folder inside the archive | `ensure` as | Spawn name / weapon |
|------|---------------------------|-------------|---------------------|
| Tesla Cybertruck | `CyberTruckV` | `hc_veh_cybertruck` | `CyberTruckV` |
| Comet Mansory | `fivem` | `hc_veh_cometmans` | `cometmans` |
| BMW S1000RR 2023 | `fivem` | `hc_veh_s1000rr23` | `ip_m1000rr_23` |
| Drift Corvette | `sddriftvet` | `hc_veh_sddriftvet` | `sddriftvet` |
| UDM DOMA | `DOMA` | `hc_wep_doma` | `WEAPON_DOMA` |
| Revenant-15 | `revenant_15` | `hc_wep_revenant15` | `WEAPON_REVENANT15` |
| Pringle SMG | `Pringle SMG` | `hc_wep_pringle` | `WEAPON_PRINGLE` |
| Police Ghost | `police_ghost` | `hc_wep_ghost` | `WEAPON_GHOST` |
| Demon Slayer Glocks | `fivem/mitsuriswitchdrum`, `fivem/tanjiroswitchdrum` | `hc_wep_mitsuri`, `hc_wep_tanjiro` | `WEAPON_MITSURISWITCHDRUM`, `WEAPON_TANJIROSWITCHDRUM` |
| Five-Seven | `FiveSeven` | `hc_wep_fiveseven` | replace only — section C |

Two folders are literally named `fivem`, and one has a space in it
(`Pringle SMG`). FiveM resource names cannot contain spaces, and two resources
cannot both be called `fivem` — the unpack script renames them to the
`ensure` column above.

## B. Singleplayer add-ons — conversion needed

Spawn names are confirmed; the packs are not usable until converted.

| Pack | Confirmed spawn name | Notes |
|------|----------------------|-------|
| Aston Martin DBR22 | `amdbr` | |
| Aston Martin DBS 2023 | `amv23` | |
| Aston Martin DBS 770 Volante | `dbsv770` | |
| Audi R8 2023 | `audir82023` | OpenIV `.oiv` installer |
| BMW M1000RR | `bmw_m1000rr` | OpenIV `.oiv` installer |
| BMW M3 Competition | `m3comp` | |
| Bentley GT Speed Convertible | `bcgtc`, `bcgts` | two models |
| Brabus G63 6x6/10x10 | `bubba` | |
| Bugatti W16 Mistral | `trial` | **see warning below** |
| Chevy Colorado ZR2 | `ccadd` | |
| Dodge Charger + Challenger | `hellcat`, `redeye` | two models, one pack |
| Ferrari F80 2025 | `ferrarif80` | |
| Honda CBR1000RR | `cbr1000rr` | OpenIV `.oiv` installer |
| Jaguar XJ220 | `xj220` | |
| Jeep Wrangler 392 | `jeep392` | |
| KTM X-Bow GT2 | `bow` | |
| Kayo K1 | `kayo_k1` | archive is named `Desktop.rar` |
| Lamborghini Fenomeno 2026 | `feno26sx` | |
| McLaren Elva | `meva` | |
| McLaren Sabre | `mclsab` | |
| Mercedes G550 2025 | `g550trg` | |
| Mercedes G55 AMG | `benzg55` | |
| PHMT09 | `phmt09` | |
| Progasi 300 | `progasi300` | |
| Rezvani (left-hand) | `rezvan2` | |

> **Bugatti W16 Mistral ships with the model name `trial`.** That is the naming
> a watermarked/trial build of a paid mod normally uses. Check what was actually
> bought before putting it on a paying customer's server.

## C. Weapon skins that replace a vanilla weapon

These add no new gun. They re-skin an existing one, which is exactly what
`hc-weapons` sells as "realistic guns with a custom look".

| Pack | Re-skins |
|------|----------|
| Travis Glock (Azal) | `WEAPON_APPISTOL` |
| Glock 19 Gen 5 switch retexture (14 colours) | `WEAPON_APPISTOL` |
| Hello Kitty Glock (Azal) | `WEAPON_APPISTOL` |
| Families Glock 18c | `WEAPON_APPISTOL` |
| Glock-19 Disintegration (Utopia Art) | `WEAPON_COMBATPISTOL` |
| Thermoptic pistol | `WEAPON_COMBATPISTOL` |
| Glock 43x | `WEAPON_SNSPISTOL` |
| Kel-Tec PMR30 | `WEAPON_PISTOL` |
| Five-Seven | `WEAPON_PISTOL` |
| M4A1-S Printstream | `WEAPON_CARBINERIFLE` |
| M4A1 Jiaran | `WEAPON_CARBINERIFLE` |
| HK416 Blue Roar | `WEAPON_CARBINERIFLE` |
| Purple Yokai (Utopia Art) | `WEAPON_CARBINERIFLE` |
| Future Specialcarbine (Azal) | `WEAPON_SPECIALCARBINE` |
| Kilo 141 Yandere | `WEAPON_SPECIALCARBINE` |
| Delta Action AKM Forest Hunter | `WEAPON_ASSAULTRIFLE` |
| Saiga-9 Kraken (Utopia Art) | `WEAPON_HEAVYSHOTGUN` |
| Purgatory Double Scorpion | `WEAPON_MINISMG` |

### Collisions — pick one per slot

| Vanilla weapon | Packs competing for it |
|----------------|------------------------|
| `WEAPON_APPISTOL` | **4** — Travis, Glock 19 Gen 5, Hello Kitty, Families 18c |
| `WEAPON_CARBINERIFLE` | **4** — Printstream, Jiaran, HK416, Purple Yokai |
| `WEAPON_PISTOL` | **2** — Five-Seven, Kel-Tec PMR30 |
| `WEAPON_COMBATPISTOL` | **2** — Disintegration, Thermoptic |
| `WEAPON_SPECIALCARBINE` | **2** — Future Specialcarbine, Kilo 141 |

Whichever resource starts last wins; the rest are dead weight. To actually use
more than one per slot they must be rebuilt as **addon** weapons with their own
`WEAPON_` names — the same conversion job as the cars.

> `revenant_15` and `police_ghost` are addon weapons **and** ship a vanilla
> replace (`w_ar_carbinerifle.ydr`, `w_pi_pistol.ydr`). They will re-skin the
> vanilla carbine and pistol as a side effect unless those files are deleted
> from their `stream/` folders. That may well be what you want — just know it
> is happening.

## D. MLOs and libraries

All 20 `anarchy_*` packs are proper FiveM resources and stream as-is. See
`server.cfg.example` for the ensure list and `docs/dependencies.md` for which
script uses which.

`5s_lib` is a library with no stream files. It still **cannot start on the live
key** — Keymaster entitlement, client action required.

## E. Partially opaque

| Pack | Note |
|------|------|
| Travis Glock, Hello Kitty Glock, Future Specialcarbine (all Azal) | The archives are fine and their FiveM stream files are readable — the bundled `dlc.rpf` is encrypted, so only the singleplayer half cannot be inspected. All three work as the replace skins listed in section C. |
| Seashark Pack | `dlc.rpf` with no vehicle metadata — a vanilla `seashark` replace |
| Mustang Sound mod | audio only (`2015mustsound`), stream with the matching Mustang |

Four packs were first reported as damaged during this audit. They are not —
that was `unar` failing on them. All four test clean with `unrar`.

---

## What to do next

1. **Decide with the client which cars are worth converting.** 22 conversions is
   real work; the exclusive lot does not need all of them on day one.
2. **Pick one skin per vanilla weapon slot** from the collision table. The rest
   either get converted to addon weapons or stay unused.
3. **Check the Bugatti's `trial` model name** before shipping it.
4. Run the rewritten `scripts/unpack-client-files.sh` on the VPS:
   `sudo apt-get install -y unrar` first. The script tests each archive before
   installing anything from it, names each resource canonically, and writes
   `docs/unpack-report.txt` listing what installed, what needs conversion and
   what failed.
