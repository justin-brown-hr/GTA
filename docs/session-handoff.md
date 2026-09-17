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

### Milestone 2 — Crime + premium (scaffolded only)
Resources exist but need deepening: `hc-drugs`, `hc-scam`, `hc-heists`, `hc-weapons`, `hc-clothing`, `hc-dealership`, `hc-zombie`

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

1. Get **Ubuntu 22.04 VPS** from client (SSH + ports 22, 30120)
2. Clone repo on VPS: `git clone git@github.com:justin-brown-hr/GTA.git`
3. Install FXServer + MySQL + QBCore + ox stack (`docs/dependencies.md`)
4. Copy `server.cfg.example` → `server.cfg`, add FiveM key + MySQL string
5. Import `database/schema.sql`, merge ox items
6. Start server, run through `docs/m1-acceptance.md`
7. After M1 sign-off → deepen M2 resources

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
