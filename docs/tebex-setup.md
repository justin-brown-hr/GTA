# Tebex → exclusive dealership

How a real-money car purchase becomes a car in someone's garage.

---

## The flow

```
  Player buys a package on the Tebex store
             │
             ▼
  Tebex runs a command on the FiveM server
    hc_tebex_grant <buyer> <model> <transaction>
             │
             ▼
  hc-dealership records it in hc_tebex_grants as 'pending'
             │
      ┌──────┴───────┐
      ▼              ▼
  buyer online   buyer offline
      │              │
  delivered      delivered on their
  immediately    next character load
      └──────┬───────┘
             ▼
  Car is in player_vehicles, status flips to 'delivered'
```

**The buyer does not need to be online.** Most people buy from the website, not
from inside the game. A grant is recorded first and delivered when it can be,
so a purchase is never lost.

**One purchase can only ever produce one car.** Grants are deduplicated on the
Tebex transaction id, so a retry, a double-click, or a staff member pasting the
command twice all result in exactly one vehicle.

---

## One-time setup

### 1. Connect the store to the server

1. Tebex panel → **Game Servers** → add your FiveM server, copy the secret key.
2. In `server.cfg`:
   ```cfg
   set sv_tebexSecret "YOUR_SECRET_HERE"
   ensure tebex
   ```
3. Restart. `tebex` should report as connected in the console.

`server.cfg` is gitignored — the secret never goes in the repo.

### 2. Create a package per car

One Tebex package per vehicle. In the package's **Commands**, add a command that
runs on purchase:

```
hc_tebex_grant {id} CyberTruckV {transaction}
```

- Replace `CyberTruckV` with the spawn model, or with the package id from
  `Config.ExclusiveLot` — the script accepts either.
- **Set "require the player to be online" to OFF.** We queue the grant
  ourselves; requiring online defeats the whole point.

> Confirm the exact placeholder names in your Tebex panel before going live —
> they vary by store configuration. Whatever `{id}` resolves to, the command
> handles it: FiveM license, Steam id, Discord id, a QB citizenid, or a server
> id. Buy one package in Tebex test mode and watch the server console.

### 3. Give the car a home in the config

In [`hc-dealership/shared/config.lua`](../server-data/resources/%5Bheartless%5D/hc-dealership/shared/config.lua):

```lua
{ model = 'CyberTruckV', label = 'Cybertruck', tebexPackageId = 'PKG_CYBERTRUCK', priceUsd = 35 },
```

`model` must match the `<modelName>` in the pack's `vehicles.meta` exactly —
it is case sensitive. Also `ensure` the stream resource in `server.cfg`, or the
car will be granted and then fail to spawn.

---

## Adding another exclusive car

1. Unpack the car into `[assets]`, read the real model from `vehicles.meta`.
2. `ensure` its resource in `server.cfg`.
3. Add the entry to `Config.ExclusiveLot.vehicles`.
4. Create the Tebex package with the command above.
5. `restart hc-dealership`, then test with the staff command below.

---

## Staff commands

**Server console / RCON only:**

| Command | Use |
|---------|-----|
| `hc_tebex_grant <serverId\|citizenid\|identifier> <model\|packageId> [txId]` | What Tebex calls. Also how you fulfil a purchase by hand. |
| `hc_tebex_pending` | Everything queued but not yet delivered, and who it is for. |
| `hc_tebex_retry` | Re-run delivery for everyone online. Use after fixing a wrong model name. |

**In game:**

| Command | Use |
|---------|-----|
| `/hcgrant <serverId> <model>` | Support / comp grant. Needs the `hc.grant` ace. |

`hc.grant` is deliberately **not** part of generic admin — these are real-money
items. `server.cfg.example` denies it to `group.admin` by default and shows how
to create a separate group for it. Every manual grant is printed to the console
and written to `hc_transaction_log`.

---

## Checking on a purchase

```sql
-- Did it arrive?
SELECT transaction_id, citizenid, grant_identifier, model, status, plate, created_at, delivered_at
FROM hc_tebex_grants ORDER BY id DESC LIMIT 20;

-- Anything stuck?
SELECT * FROM hc_tebex_grants WHERE status = 'pending';

-- The car itself
SELECT citizenid, vehicle, plate, garage FROM player_vehicles WHERE plate = 'HC______';
```

A row that stays `pending` means the buyer has not logged in since they bought,
or the identifier Tebex sent does not match any identifier that character
carries. `hc_tebex_pending` shows which.

---

## Chargebacks and refunds

There is no automatic removal — deliberately, because an accidental
auto-delete of a legitimate car is worse than a manual step.

```sql
-- 1. find it
SELECT * FROM hc_tebex_grants WHERE transaction_id = 'THE_TX';
-- 2. remove the car (use the plate from that row)
DELETE FROM player_vehicles WHERE plate = 'HC______';
-- 3. mark it
UPDATE hc_tebex_grants SET status = 'revoked' WHERE transaction_id = 'THE_TX';
```

If the player is online they must re-log for the garage to stop showing it.

---

## Testing before launch

| # | Test | Expected |
|---|------|----------|
| 1 | `hc_tebex_grant <yourId> CyberTruckV TEST1` while online at the exclusive lot | Car spawns, you are in it |
| 2 | Same command again with `TEST1` | Ignored — "already recorded", still one car |
| 3 | `hc_tebex_grant <yourCitizenid> cometmans TEST2` while offline, then log in | Delivered ~8s after spawning in, parked in the garage |
| 4 | `hc_tebex_grant <yourId> PKG_DRIFTVET TEST3` (package id, not model) | Resolves to `sddriftvet` and delivers |
| 5 | `hc_tebex_grant <yourId> notacar TEST4` | Refused, prints the list of valid models |
| 6 | Exclusive lot menu in game | Shows USD prices and the store link |
| 7 | Try to buy an exclusive model at the **public** lot | Refused, "real money only" |
| 8 | A real Tebex test-mode purchase | Same as #1, and `hc_tebex_pending` is empty afterwards |

Run #8 before the store goes live. It is the only test that proves the Tebex
side is wired correctly rather than just our side.
