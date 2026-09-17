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

## Assets (client supply or licensed)

- Custom vehicle packs (exclusive lot)
- Clothing / EUP packs
- Weapon metas / models
- Optional island / zombie MLO

## Install order in `server.cfg`

1. `oxmysql`, `ox_lib`
2. `qb-core`
3. ox_inventory / ox_target / voice
4. qb-* gameplay
5. `ensure [heartless]` (or each `hc-*` resource)
