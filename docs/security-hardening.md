# P0 hardening — server-side validation pass

**Date:** 2026-09-18
**Scope:** every `hc-*` resource that moves money, items, or a player's position.

Before this pass, several net events took the client at its word. The worst of
them paid cash for simply firing an event, with no check that the player was in
the right place, in the right state, or had done anything at all.

The rule this pass applies everywhere:

> The client may **ask** for something. It may never **assert** it.
> Money, items and teleports are decided server side, or they do not happen.

---

## What was fixed

### 1. Deadzone infinite cash — critical

`hc-zombie:server:exit` paid $250–700 to anyone who triggered it. No check that
the player had ever entered the zone, no distance check, no cooldown. A one-line
client loop printed unlimited money.

**Now:** extraction requires an entry the server recorded, requires standing at
the extraction point, and pays **per salvage item handed in** — not for the act
of leaving. Salvage only drops from caches, and each cache is on a per-player
cooldown, so cache cooldowns are the hard ceiling on Deadzone income.

`Config.SalvagePerLootMin/Max` and `Config.ExtractCashMax` now control the rate.

### 2. Deadzone free teleport

`hc-zombie:server:enter` teleported anyone who asked, from anywhere.

**Now:** you must be within `Config.GateDistance` of the city gate.

### 3. Job pay loop

`hc-jobs` counted stops on the client. The server only checked that 15 seconds
had passed, so start → wait → complete → repeat paid out forever.

**Now the server owns the route:** it picks the stops, hands the client only the
indices, and confirms each stop individually after checking the player is
standing on it and that the progress bar had time to run. `completeRun` refuses
unless every stop it issued was confirmed, and the turn-in happens at the
turn-in point.

Rejections answer the client (`hc-jobs:client:stopRejected`) so an honest player
who desyncs can retry instead of being stuck with an unusable job.

### 4. Business balance race + unbounded amounts

`withdraw` read the balance, then wrote it. Two parallel calls both passed the
check and drained the business twice. Amounts were never floored or capped, so a
crafted float or a huge number went straight into SQL.

**Now:** ownership, funds and the debit happen in one conditional `UPDATE` —
the database is the arbiter. Amounts are floored, must be positive, and are
capped by `Config.MaxTransaction`. `buy` and `sell` use the same conditional
pattern so two buyers cannot both own a business and a double-click cannot pay
the sale refund twice.

### 5. Remote shopping

`hc-dealership:server:buyPublic`, `hc-weapons:server:buy` and
`hc-scam:server:buy` never checked where the player was — you could buy a rifle
from inside a jail cell or a hospital bed.

**Now:** all three require the player to be at the counter. Heist starts require
being at the target (starting a heist burns a cooldown and pings PD, so that
mattered too), and drug sales are rate limited so a macro cannot dump a whole
bag in one frame and skip every police-alert roll.

### 6. Plate collisions eating paid cars

`randomPlate()` never checked whether the plate was already in use. A collision
confuses keys, garages and impound — and with a unique index on
`player_vehicles.plate` the INSERT fails and the buyer loses the money they
just paid.

**Now:** plates are drawn until a free one is found, the vehicle INSERT is
checked, and a failed registration **refunds** the purchase instead of pocketing
it. Tebex grants that fail register nothing and print a re-run instruction, and
a repeated `transaction_id` is ignored so one purchase can never produce two
cars.

### 7. No guard rails at all

There was no rate limiting, no abuse logging, and no record of where money came
from.

**Now:** `hc-core/server/security.lua` provides:

| Export | Use |
|--------|-----|
| `exports['hc-core']:RateLimit(src, key, ms)` | per-player, per-action throttle |
| `exports['hc-core']:Flag(src, reason)` | records a rejected claim; shouts in console at `Config.Security.flagThreshold` |
| `exports['hc-core']:LogMoney(src, category, amount, detail)` | writes `hc_transaction_log`, optional Discord webhook over `webhookMinAmount` |

Every payout and charge in the `hc-*` scripts now logs. When someone claims the
economy is broken, `hc_transaction_log` answers it instead of guesswork.

`server.cfg.example` gained `sv_scriptHookAllowed 0`, `sv_entityLockdown
"relaxed"`, `sv_filterRequestControl 4` and the auth variance settings.

---

## Deploying this to the live VPS

```bash
# 1. Pull the code
cd /opt/heartless/GTA && git pull

# 2. Apply the DB migration (adds hc_transaction_log + heist index)
mysql -u root -p heartless_city < database/migrations/2026-09-18-p0-hardening.sql

# 3. Merge the new server.cfg hardening block into the live server.cfg
#    (server.cfg is gitignored — copy the "Baseline hardening" section by hand)

# 4. Restart the touched resources
#    refresh; restart hc-core hc-jobs hc-business hc-drugs hc-scam
#              hc-heists hc-weapons hc-dealership hc-zombie

# 5. Schedule backups (see scripts/backup-db.sh)
```

`hc-core` must restart **first** — the others call its new exports.

---

## Regression tests — run these before the client demo

Each one used to pay out or succeed. All of them must now fail.

| # | Test | Expected |
|---|------|----------|
| 1 | In the city, F8: `TriggerServerEvent('hc-zombie:server:exit')` ×10 | No money. Console flags `zombie:exit-not-inside` |
| 2 | In the city, F8: `TriggerServerEvent('hc-zombie:server:enter')` while away from the docks gate | No teleport. Flags `zombie:enter-distance` |
| 3 | Enter the Deadzone, extract with an empty bag | "Extracted empty-handed" — $0 |
| 4 | Enter, loot 2 caches, extract | Paid per item, salvage removed from inventory |
| 5 | Start a job, wait 20s, F8: `TriggerServerEvent('hc-jobs:server:completeRun','delivery')` | Refused, "you still have N stops left" |
| 6 | Work the route properly | Pays once; a second `completeRun` is refused |
| 7 | Two clients withdraw the full business balance at the same moment | Exactly one succeeds |
| 8 | F8: `TriggerServerEvent('hc-business:server:withdraw','ls_customs', 99999999)` from across the map | Refused on distance, then on amount cap |
| 9 | F8: `TriggerServerEvent('hc-weapons:server:buy','WEAPON_CARBINERIFLE',false)` from anywhere but the armory | Refused |
| 10 | Buy the same public car repeatedly | Every car gets a distinct `HC******` plate |
| 11 | Run the same `hc_tebex_grant <id> CyberTruckV TX123` twice | Second run ignored, one car granted |
| 12 | `SELECT * FROM hc_transaction_log ORDER BY id DESC LIMIT 20;` | Every payout above appears |

---

## Still open (not P0, do not skip)

- **Entity lockdown — our side is done, QB's is not.** Correction to an
  earlier note: `relaxed` is not a safe halfway house — it already blocks every
  client script-created entity; only ambient population survives it.

  Audit of every resource on the server (2026-09-19), networked entities
  created on the client:

  | Resource | What | Status |
  |---|---|---|
  | hc-jobs | work vehicles | **moved to server** |
  | hc-dealership | purchased / Tebex cars | **moved to server** |
  | hc-zombie | zombies | **server**, own instance in `strict` |
  | qb-core | `/car`, client `SpawnVehicle`, `AttachProp` | client |
  | qb-fuel | pump nozzle | client |
  | qb-policejob | cones, barriers, spikes | client |
  | qb-radialmenu | stretcher bag | client |
  | qb-shops | delivery box | client |
  | qb-vehiclekeys | key-fob prop | client |

  Local-only (non-networked) creation — unaffected by lockdown — was also
  found in bob74_ipl, ox_lib, ox_inventory, qb-interior, qb-multicharacter,
  qb-shops' ped and hc-drugs' dealer; those are fine.

  Turning lockdown on today would break the QB rows. Options: patch those
  six resources to server-side creation (vendor forks — re-apply on every QB
  update), replace them with ox/community versions that are already
  server-side, or rely on a proper anticheat instead. Until then it stays off
  for the main world.
- **A real anticheat** on top of this (the guards here stop *our* scripts being
  abused, not menu users spawning cars or god mode).
- **`player_vehicles.plate` unique index** — the migration has the statement,
  commented, with the duplicate check to run first.
- **Off-box backups.** `scripts/backup-db.sh` dumps and prunes locally; a backup
  that only exists on the machine that dies is not a backup.
- **Business deposit/withdraw are hardcoded to $1000** in the client menu — the
  server accepts any sane amount, the UI just never asks for one.
