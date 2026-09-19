# External dependencies

These are **not** vendored in this repo (licenses / size). Install into the folders below.

## Required

| Resource | Folder | Notes |
|----------|--------|-------|
| FXServer artifacts | host machine | Match game build |
| `oxmysql` | `[standalone]` | DB driver |
| `ox_lib` | `[standalone]` | |
| `ox_inventory` | `[standalone]` | Needs QB bridge |
| `ox_target` | `[standalone]` | |
| `pma-voice` | `[standalone]` | |
| `qb-core` | `[qb]` | Framework |
| `qb-multicharacter` | `[qb]` | Or equivalent |
| `qb-spawn` | `[qb]` | |
| `qb-apartments` / housing | `[qb]` | Optional early |
| `qb-policejob` / `qb-ambulancejob` | `[qb]` | Can start minimal |
| `qb-banking` or renewed banking | `[qb]` | |
| `qb-management` | `[qb]` | Helps businesses |
| `qb-vehiclekeys` | `[qb]` | |
| `qb-garages` | `[qb]` | |
| `qb-shops` | `[qb]` | Base shops |
| `qb-weapons` | `[qb]` | Base; extend via `hc-weapons` |
| `qb-clothing` or illenium-appearance | `[qb]` / standalone | Prefer illenium if client wants fashion updates |

## Monetization

| Service | Use |
|---------|-----|
| Tebex | Exclusive dealership packages → `hc-dealership` grant |

The `tebex` resource (downloaded from your Tebex panel → Game Servers) must be
installed and `ensure`d for store commands to reach the server. Setup and test
matrix: `docs/tebex-setup.md`.

## Client packs (`Files/`)

Full audit of what is in every pack — confirmed spawn names, what is FiveM-ready
and what is not — is in `docs/client-assets.md`.

Unpack with `scripts/unpack-client-files.sh`, which needs **unrar** on the VPS:

```bash
sudo apt-get install -y unrar
```

p7zip cannot decompress RAR5 (most of the drop), and `unar` silently drops files.
Then `ensure` each installed resource by name — **not** `ensure [assets]`, which
has broken joins on this server before.

Licensed / client-supplied only: vehicles, clothing, weapons, MLOs. Do not pirate packs.

## Install order in `server.cfg`

1. `oxmysql`, `ox_lib`
2. `qb-core`
3. ox_inventory / ox_target / voice
4. qb-* gameplay
5. `ensure [assets]` (client cars/guns/MLOs)
6. `ensure [heartless]` (or each `hc-*` resource)
