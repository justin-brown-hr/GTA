# Session handoff — Heartless City RP

Use this when opening a **new workspace** so work continues without losing context.

---

## Project

| Item | Value |
|------|-------|
| **Server name** | Heartless City RP |
| **Type** | Serious California-style FiveM RP |
| **Client Discord** | https://discord.gg/dAhv96zVf |
| **GitHub** | https://github.com/justin-brown-hr/GTA |
| **Role** | Freelancer building for client (2 milestones agreed) |

---

## Stack (locked)

- **QBCore** + **oxmysql**, **ox_lib**, **ox_inventory**, **ox_target**, **pma-voice**
- **Tebex** for exclusive real-money dealership (M2)
- Custom scripts only under `server-data/resources/[heartless]/hc-*`

---

## Milestones

### Milestone 1 — Legal city (in progress)
**Done in code:**
- `hc-core` — branding, notify, business DB seeds
- `hc-jobs` — 6 jobs with full loops (delivery, tow, fishing, mining, taxi, garbage)
- `hc-business` — 4 buyable businesses, deposit/withdraw, hire/fire, stash, passive income

**Not done / blocked:**
- QBCore + ox deps **not installed on live VPS yet**
- Staging demo + client sign-off (`docs/m1-acceptance.md`)

### Milestone 2 — Crime + premium
**Done in code:** `hc-drugs`, `hc-scam`, `hc-heists`, `hc-weapons`, `hc-clothing`, `hc-dealership`, `hc-zombie` (playable loops + PD risk + Tebex grant).
**Assets:** client drop in `Files/` — catalog `docs/client-assets.md`, unpack `scripts/unpack-client-files.sh`.
**Still:** live VPS + confirm a few car spawn names from `vehicles.meta` after unpack.

---

## Client status (last known)

1. **FiveM key received** — stored locally only (see below)
2. **Windows VPS received** — freelancer could not RDP from local PC
3. **Client asked to switch to Ubuntu VPS** — waiting on new SSH credentials
4. Client has scripts/MLOs to send later
5. Asset budget discussed: **$600–800** recommended (elite cars/clothing/guns, licensed only)
6. Partner added to client chat

---

## Secrets (NOT in GitHub)

Copy these manually to the new machine:

| File | Contents |
|------|----------|
| `secrets/credentials.local.md` | FiveM registration key, old Windows VPS RDP login |

After Ubuntu VPS arrives, add SSH credentials to that same local file.

`.gitignore` excludes: `secrets/`, `**/credentials*`, `server-data/server.cfg`

---

## Key paths

```
docs/chathistory.md      — client feature wishlist
docs/detail.md           — original job brief
docs/milestones.md       — M1 / M2 scope
docs/m1-acceptance.md    — M1 demo checklist
docs/dependencies.md     — external resources to install
docs/roadmap.md          — phased delivery
database/schema.sql      — hc_businesses, tebex grants, heist cooldowns
database/ox_items_heartless.lua — merge into ox_inventory items
server-data/server.cfg.example — template (copy → server.cfg on VPS)
```

---

## Next actions (priority order)

1. Unpack client packs on VPS: `scripts/unpack-client-files.sh` then confirm exclusive car spawn names
2. Install FXServer + QBCore + ox stack (`docs/vps-ubuntu.md`, `docs/dependencies.md`)
3. Copy `server.cfg.example` → `server.cfg`, add FiveM key + MySQL string, `ensure [assets]`
4. Import `database/schema.sql`, merge `database/ox_items_heartless.lua`
5. Demo `docs/m1-acceptance.md` then `docs/m2-acceptance.md`

---

## Copy-paste prompt for new workspace

Paste this as your **first message** in the new Cursor chat:

```
I'm continuing the Heartless City RP FiveM freelance project.

Read these first:
- docs/session-handoff.md (full context)
- docs/milestones.md
- docs/m1-acceptance.md

Repo: https://github.com/justin-brown-hr/GTA (already pushed to main)

Project: Serious Cali RP server "Heartless City RP" for a client.
Stack: QBCore + oxmysql + ox_lib + ox_inventory + ox_target + pma-voice.

Milestone 1 status:
- hc-jobs (6 civilian jobs with full loops) — DONE in code
- hc-business (4 buyable businesses) — DONE in code
- NOT live yet — need Ubuntu VPS + QBCore install for staging demo

Milestone 2: hc-drugs, hc-heists, hc-scam, hc-dealership, hc-weapons, hc-clothing, hc-zombie — scaffolded only.

Client gave FiveM key + Windows VPS (couldn't RDP). Waiting on Ubuntu VPS SSH credentials.

Secrets are local only in secrets/credentials.local.md (not in git) — I will copy that file manually.

Continue from: [pick one]
- Install server on Ubuntu VPS when credentials arrive
- Finish anything left for Milestone 1
- Start Milestone 2 deepening
- Draft client messages
```

Replace the last line with whatever you need next.

## 2026-09-19 VPS repo now tracks git — deploy with `git pull`

The VPS checkout (`/opt/heartless/GTA`) was on the first commit with every
change copied over by hand. It is now on `main` (verified file-by-file first:
nothing on disk changed). From here on, deploy by pulling:

```bash
cd /opt/heartless/GTA
git config --global --add safe.directory /opt/heartless/GTA   # once: the checkout is owned by another uid
git pull
# then restart only what changed — and never hc-core on its own (see below)
```

`.gitignore` was fixed at the same time: `[stream]`, `[qb]` etc. were never
actually ignored (brackets are wildcards in .gitignore), and FXServer's 32 GB
`server-data/cache` was not listed. A `git add -A` on the VPS would have tried
to commit all of it.

## 2026-09-19 Nightly database backups live

- `heartless-db-backup.timer` runs `scripts/backup-db.sh` at 04:30 daily,
  14-day retention in `/opt/heartless/backups/`. Details: `docs/vps-ubuntu.md`.
- Fixed two script bugs first: it connected over TCP, which the VPS's socket-
  authenticated root cannot use (every run would have failed), and a failed dump
  could leave a broken file posing as the latest backup.
- Restore tested into a throwaway DB: 18/18 tables match.
- Not yet: an off-VPS copy — needs a destination from the client.

## 2026-09-19 Vehicles spawned server-side + garage-state bug fixed

- `hc-jobs` and `hc-dealership` no longer create vehicles on the client. The
  server spawns them (`CreateVehicleServerSetter`), sets the plate, keeps them
  from being orphan-deleted, and grants keys via `qb-vehiclekeys` `GiveKeys`.
- Jobs: the server now checks the **vehicle** (not just the player) is back at
  the depot before paying, and deletes it on payout / cancel / disconnect /
  resource stop. The client no longer resets its job state before the server
  answers, so a refused turn-in can be retried instead of soft-locking.
- **Bug fixed (my earlier Tebex code):** cars were written to
  `player_vehicles` as `state = 0` (OUT). A car delivered while the buyer was
  offline would be un-retrievable, and qb-garages adds a $500 depot fee to every
  OUT car on restart. Now written GARAGED and flipped to OUT only once it has
  actually spawned. No customer was affected (0 grants, 0 HC plates out).
- Verified server-side with `hc_dealer_spawntest` (car, bike, boat, 2 exclusives):
  spawn + delete OK. Plate and net id could not be confirmed with 0 players
  (both are resolved by the owning client), so the client re-applies the plate
  after the warp if it did not stick.
- **Entity lockdown for the main world stays off**: six QB resources spawn
  networked entities client-side. Full audit in `docs/security-hardening.md`.

## 2026-09-19 Deadzone rewritten + deployed

- **Moved to the right island.** Config pointed at Cayo Perico (4840,-5174),
  which does not exist on game build 1604. The client's island map is the Alamo
  Sea one (`turbosaif_alamo_island`, x -6..527, y 3772..4205 — read from its
  .ymap extents). Ground height and water are resolved in game, so an imperfect
  point lands on the nearest dry ground instead of in the sea.
- **Server-authoritative.** Zombies are created by the server in routing bucket
  66 (population off, entity lockdown `strict` for that bucket only). A director
  keeps a population around players, raises the wave every 3 min, culls
  stragglers, credits kills from `GetPedSourceOfDeath`.
- **Rules:** salvage + kill bonus paid only at an extract (8 s hold, two-step,
  server-timed). Death inside forfeits salvage. Leaving the island pulls you back.
- Deployed; loads clean, director idle-ticks with no errors. **Not yet tested
  in game** — checklist in `docs/m2-acceptance.md`.

### Deploy rule learned the hard way

**Never `restart hc-core` on its own.** Every other `hc-*` depends on it, so
FiveM stops all nine — and does not start them again. Either restart the whole
service (`systemctl restart heartless-fx`, ~10 s boot, 0 players), or restart
hc-core and then `ensure` each dependent. Restarting a leaf resource
(hc-zombie, hc-jobs, …) on its own is fine.

## 2026-09-19 Deployed to the live VPS + client clothing installed

**The VPS now runs this repo's code** (it was running the older, exploitable
version). Deployed by file copy, checksum-verified, backups first:
`/root/hc-backups/2026-09-19-predeploy/` (code, live server.cfg, ox_inventory
data files, verified DB dump).

- DB migrations applied (`hc_transaction_log`, Tebex queue columns) — idempotent.
- Custom guns fixed in ox_inventory: they had been registered as plain items in
  `data/items.lua` (buyable, never equippable). Now real weapons in
  `data/weapons.lua`, plus Pringle SMG and the two Demon Slayer glocks.
- Tebex queue exercised on the real console (bad model, offline queue,
  duplicate transaction) — all correct; test rows removed.
- **Console now logged** to `/var/log/heartless/fx-console.log` (systemd drop-in
  `heartless-fx.service.d/console-log.conf`, logrotate 14 days). Before this the
  output only existed inside the detached screen session.
- Clothing, skins, 7 maps and 5 weapon/vehicle packs installed and enabled — see
  `docs/client-assets.md` "2026-09-19 upload". Cold boot: 86 resources, 0
  failures, all up in 10 s.

Sending console commands: `screen -S heartless -p 0 -X stuff "cmd$(printf \\r)"` —
**one command per call with a pause**; a burst piles up as one unsubmitted line.

Needs the client:
1. Keymaster: server key must come from the account that owns `5s_lib` and
   `wais-jobpack` (one fix, unblocks both).
2. Game build: server runs default 1604; wais-jobpack needs 3258. Not changed —
   it affects every player and needs an in-game test.
3. Clothing is 31 GB and unoptimised (3,277 size warnings) — optimise before launch.
4. Rotate the root password (it has been shared in chat) and move to SSH keys.

## 2026-09-18 Asset audit — every pack opened and catalogued

Read the real spawn names out of all 75 packs, including the ones sealed in
`dlc.rpf` and `.oiv` installers. Full catalogue: `docs/client-assets.md`.

Three things the client needs to be told:

1. **Only 4 of 29 vehicle packs are FiveM-ready.** The other 25 are singleplayer
   add-ons that need converting to resources first (~2 days of work, not covered
   by the current milestones). Spawn names for all of them are now confirmed.
2. **The old unpack script could not read RAR5**, which is why exactly the three
   `.zip` packs are live and none of the `.rar` ones are. Script rewritten.
3. **The weapon skins collide** — 4 packs want `WEAPON_APPISTOL`, 4 want
   `WEAPON_CARBINERIFLE`. Only one can win per slot; the rest are wasted unless
   converted to addon weapons.

Also: the Bugatti W16 Mistral's model name is literally `trial`, which is what a
watermarked trial build of a paid mod uses. Worth checking what was bought.

Wired up: `ip_m1000rr_23` added to the exclusive lot; `WEAPON_PRINGLE` and the
two Demon Slayer glocks added to `hc-weapons`; addon weapons moved out of
`ox_items_heartless.lua` into `database/ox_weapons_heartless.lua` (ox_inventory
keeps weapons in `data/weapons.lua`, so they never would have worked as items).

## 2026-09-18 Tebex delivery queue

Exclusive car purchases now survive an offline buyer — previously a purchase
made from the website was simply lost.

- Grants are recorded as `pending` and delivered on the buyer's next character
  load; one transaction can only ever produce one car.
- Resolves server id / citizenid / license / steam / discord identifiers.
- New: `hc_tebex_pending`, `hc_tebex_retry` (console), `/hcgrant` (ace
  `hc.grant`, deliberately separate from generic admin).
- Deploy needs `database/migrations/2026-09-18-tebex-queue.sql`.
- **Client still owes us:** the Tebex store itself, package ids, and the game
  server secret. See `docs/tebex-setup.md`.

## 2026-09-18 P0 hardening

Server-side validation pass across every `hc-*` resource — see
`docs/security-hardening.md` for what changed, how to deploy it, and the 12
regression tests to run before the next demo.

- Fixed: Deadzone infinite-cash exit, Deadzone free teleport, job pay loop,
  business withdraw race + unbounded amounts, remote shop purchases, plate
  collisions eating paid cars.
- Added: `hc-core/server/security.lua` (rate limit / abuse flag / money log),
  `hc_transaction_log`, `scripts/backup-db.sh`, server.cfg hardening block.
- Deploy needs: `database/migrations/2026-09-18-p0-hardening.sql`, the new
  server.cfg block copied by hand, and `hc-core` restarted first.

## 2026-09-18 M2 push

- Synced full `[heartless]` pack + schema/items to VPS; restarted M2 resources.
- Applied qb-core/garages/banking/apartments/clothing SQL + `inventories`.
- Stream exclusives live; `5s_lib` blocked by Keymaster entitlement on live key.
- Next: client in-game M2 checklist; link `5s_lib` to cfxk; optional Tebex secret + package IDs.
