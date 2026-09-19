# Heartless City RP — 2 Client Milestones

Agreed delivery split for freelance work.

## Milestone 1 — Legal city live (Foundation + Civilian economy)

**Goal:** Joinable serious RP city where civilians earn money and buy businesses.

Includes:
- Server foundation hooks (`hc-core`)
- Full civilian jobs (delivery, tow, fishing, mining, taxi, garbage) with real loops + pay
- Purchasable businesses (4+) with owner desk, balance, withdraw, basic employee slot
- Job center blips / ox_target
- SQL for businesses
- Config ready for QBCore + ox stack

**Client acceptance:** Player can create/join (once QB is installed), take a job, complete a run, get paid, and buy a business.

---

## Milestone 2 — Crime, premium shops, Deadzone

**Goal:** Illegal loops + owner monetization + survival side content.

Includes:
- Custom drugs (3 strains) + PD risk
- Scam equipment shop + use/risk scaffolding
- Heists (store, fleeca, jewelry) with cooldown + payout stages
- Realistic + paid custom weapons shop
- Fashion shop hooks
- Public dealership + **exclusive Tebex-only** dealership
- Zombie Deadzone (routing bucket enter/exit + spawn hooks)

**Client acceptance:** Crime loops earn money with risk; exclusive cars only via Tebex grant; Deadzone enter/extract works.

---

## Status

| Milestone | Status |
|-----------|--------|
| M1 | Jobs + businesses in code; still needs QB stack on staging for demo |
| M2 | **On VPS for client demo** — loops + stream packs live; run `docs/m2-acceptance.md` in-game. `5s_lib` needs Keymaster entitlement on live cfxk. |
