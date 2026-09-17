# Heartless City RP — Architecture

## Decisions (locked for delivery)

| Area | Choice | Why |
|------|--------|-----|
| Framework | **QBCore** | Standard for serious RP, large script ecosystem, Tebex-friendly |
| Database | **MySQL + oxmysql** | Industry default for FiveM |
| Inventory | **ox_inventory** | Modern, performant, widely supported with QB |
| Targeting | **ox_target** | Clean interactions for jobs/businesses/heists |
| Voice | **pma-voice** | Stable proximity voice |
| UI / Lib | **ox_lib** | Menus, notifications, callbacks |
| Monetization | **Tebex** | Exclusive IRL$ dealership (client-owned cars) |
| Map base | **Los Santos (Cali-feel RP)** | Serious RP; zombie zone via routing bucket / island MLO later |

## Resource layout

```
server-data/
  server.cfg
  resources/
    [cfx]/          # FXServer defaults (mapmanager, sessionmanager, etc.)
    [qb]/           # qb-core + official/community QB resources
    [standalone]/   # oxmysql, ox_lib, ox_inventory, ox_target, pma-voice
    [heartless]/    # ALL custom Heartless City scripts (our deliverables)
```

Custom code lives only under `[heartless]` so updates to QB/ox stay clean.

## Custom resources (Heartless City)

| Resource | Purpose |
|----------|---------|
| `hc-core` | Shared config, branding, helpers, locale |
| `hc-jobs` | Civilian money jobs |
| `hc-business` | Purchasable businesses |
| `hc-drugs` | Custom drug craft / sell loops |
| `hc-heists` | Heist flows (prep → hit → cooldown) |
| `hc-scam` | Scam equipment / illegal tools economy |
| `hc-dealership` | Public + exclusive Tebex car shop |
| `hc-clothing` | Fashion / clothing shop hooks |
| `hc-weapons` | Realistic guns + paid custom weapon shop |
| `hc-zombie` | Separate survival zone (phase later) |

## Economy principles

- Legal jobs = steady low–mid income
- Businesses = passive + management income (purchase + upkeep)
- Drugs / scam / heists = high risk, police heat, cooldowns
- Exclusive dealership = **real money only** (Tebex packages → in-game vehicle grant)
- Custom weapons & custom cars = purchased through client shops (not free spawn)

## Environments

1. **Dev** — local FXServer + local MySQL
2. **Staging** — small VPS for client demos
3. **Live** — production with Tebex live keys

## Security notes

- Never trust client for money, items, or vehicle grants
- All Tebex grants validated server-side via secret
- Admin ACE permissions for staff; no open `/car` for players
