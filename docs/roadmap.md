# Heartless City RP — Delivery Roadmap

Server name: **Heartless City RP**  
Discord: https://discord.gg/dAhv96zVf  
Stack: QBCore + ox_inventory + ox_lib + ox_target + Tebex

Use this with the client for scope, milestones, and invoicing.

---

## Phase 0 — Foundation (Week 1)

- [x] FXServer + artifacts installed *(hosting — client/freelancer)*
- [x] MySQL + oxmysql connected *(hosting)*
- [x] QBCore + ox_lib + ox_inventory + ox_target + pma-voice *(install deps)*
- [x] `hc-core` branding, locales, shared config
- [ ] Basic character create / spawn / HUD *(QB resources)*
- [ ] Staff ACE + admin menu
- [ ] Staging server for client walkthrough

**Client deliverable:** Joinable empty RP city with chat, voice, inventory.

---

## Phase 1 — Civilian economy (Weeks 2–3) — **MILESTONE 1**

- [x] `hc-jobs`: 6 starter jobs with real stop loops + pay
- [x] Paychecks per completed run (+ anti-spam)
- [ ] Banks / ATMs / billing basics *(use qb-banking)*
- [x] `hc-business`: 4 buyable shops
- [x] Business stash, employees, deposit/withdraw, passive income

**Client deliverable:** Players can make legal money and buy/run businesses.  
**Acceptance:** see `docs/m1-acceptance.md` · **Milestones:** `docs/milestones.md`

---

## Phase 2 — Illegal + firearms (Weeks 3–4)

- [x] `hc-drugs`: 3+ custom drug strains (gather → process → sell)
- [x] Police heat / risk on sells
- [x] `hc-scam`: purchasable scam kits / tools with cooldowns & risk
- [x] `hc-weapons`: realistic weapon pack + shop; customs locked behind purchase
- [ ] Basic PD / EMS job hooks (can use QB defaults first)

**Client deliverable:** Illegal loops + gun economy working on staging.

---

## Phase 3 — Heists, fashion, cars (Weeks 5–6)

- [x] `hc-heists`: 2–3 heists (store, bank, specialty) with roles & cooldown
- [x] `hc-clothing`: updated fashion EUP / clothing packs + shop
- [x] Public dealership (in-game cash/bank)
- [x] `hc-dealership` exclusive lot: Tebex packages → unique cars only
- [ ] Custom vehicle pack install + handling pass

**Client deliverable:** Full “city loop” demo for Discord launch trailer.

---

## Phase 4 — Zombie survival side-map (Weeks 7–8)

- [x] `hc-zombie`: separate routing bucket / island or map edge
- [x] Entry NPC / portal from main city
- [x] Loot, zombies, extract-back-to-city rewards
- [x] Balance so it does not break main RP economy

**Client deliverable:** Optional survival mode live alongside RP.

---

## Phase 5 — Polish & launch (Week 9+)

- [ ] Rules, Discord bots, whitelist/queue if needed
- [ ] Anti-cheat / logging baseline
- [ ] Performance pass (onesync, entity lockdown)
- [ ] Staff training doc
- [ ] Soft launch → public launch

---

## Out of scope unless paid as add-on

- Full custom MLO building packs (unless client supplies assets)
- Mobile app / website
- 24/7 live ops after launch (retainer)

---

## Suggested freelance estimate (adjust to your rate)

| Phase | Effort (approx.) |
|-------|------------------|
| Phase 0 | 3–5 days |
| Phase 1 | 5–8 days |
| Phase 2 | 5–8 days |
| Phase 3 | 6–10 days |
| Phase 4 | 5–8 days |
| Phase 5 | 3–5 days |

Assets (cars, guns, clothes, MLOs) are **client-provided or separately licensed** — scripting integrates them; do not pirate packs.
