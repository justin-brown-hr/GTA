# Heartless City RP

Serious California-style FiveM roleplay server for client delivery.

**Discord:** https://discord.gg/dAhv96zVf

## What's in this repo

| Path | Purpose |
|------|---------|
| `docs/` | Client brief, architecture, roadmap |
| `server-data/` | FXServer data, `server.cfg`, resources |
| `server-data/resources/[heartless]/` | Custom scripts we build |
| `database/` | SQL schema / seeds |
| `scripts/` | Dev helpers |

## Stack (decided)

- **QBCore** framework
- **oxmysql**, **ox_lib**, **ox_inventory**, **ox_target**
- **pma-voice**
- **Tebex** for exclusive real-money dealership

## Quick start (developer)

1. Install [FXServer artifacts](https://runtime.fivem.net/artifacts/fivem/build_server_windows/master/) (or Linux build).
2. Install MySQL and import `database/schema.sql`.
3. Clone / drop **qb-core**, ox_* resources into `server-data/resources/` (see `docs/dependencies.md`).
4. Copy `server-data/server.cfg.example` → `server-data/server.cfg` and fill license key + DB string.
5. Start FXServer with `+set serverProfile heartless` / path to `server-data`.

## Custom resources

All Heartless features live under `resources/[heartless]/`:

- `hc-core` — shared config & branding
- `hc-jobs` — civilian jobs
- `hc-business` — purchasable businesses
- `hc-drugs` — custom drugs
- `hc-heists` — heists
- `hc-scam` — scam equipment
- `hc-dealership` — public + exclusive Tebex cars
- `hc-clothing` — fashion hooks
- `hc-weapons` — realistic / custom weapon shops
- `hc-zombie` — survival side zone

## Docs

- [Client job brief](docs/detail.md)
- [Chat / feature wishlist](docs/chathistory.md)
- [Architecture](docs/architecture.md)
- [Delivery roadmap](docs/roadmap.md)
- [Dependencies](docs/dependencies.md)
- [Client proposal template](docs/client-proposal.md)
