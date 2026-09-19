# Milestone 2 — Acceptance checklist

Use this with the client after M1 sign-off.

> Run the exploit regression tests in [`docs/security-hardening.md`](security-hardening.md)
> **before** any demo where the client (or anyone else) is on the server.

## Drugs (`hc-drugs`)

- [ ] Three strains have gather + process + sell
- [ ] Items exist in ox_inventory (`hh_*`, `cc_*`, `nn_*`)
- [ ] Street sell pays cash; chance of PD ping
- [ ] Cannot spam gather (progress + server cooldown)

## Scam (`hc-scam`)

- [ ] Black-market shop sells 4 tools
- [ ] Using a tool runs a progress action, pays dirty cash, then cooldown
- [ ] Chance of PD ping on use

## Heists (`hc-heists`)

- [ ] Store, Fleeca, Jewelry start from ox_target
- [ ] Loot stages with [E]; payout only after stages + min time
- [ ] Per-player cooldown in `hc_heist_cooldowns`
- [ ] Cop requirement can be enabled for live (`Config.RequireCops`)

## Weapons (`hc-weapons`)

- [ ] Realistic guns buyable with bank
- [ ] Custom addon guns buyable, not free spawn: DOMA, Revenant-15, Ghost,
      Pringle SMG, Mitsuri Switch, Tanjiro Switch
- [ ] `ox_weapons_heartless.lua` merged into `ox_inventory/data/weapons.lua`
      (without it every custom gun purchase fails)
- [ ] Client replace packs stream so vanilla pistols/rifles look custom
- [ ] Only one skin pack ensured per vanilla weapon slot (see client-assets.md C)

## Dealership (`hc-dealership`)

- [ ] Public lot: in-game bank only, vanilla cars
- [ ] Bought car appears on the lot with you in it, you have keys, plate is `HC######`
- [ ] Sanchez / Faggio spawn as bikes and the Seashark as a boat (server needs the type)
- [ ] A car delivered while you were away shows **Garaged** (not Out) in the garage
- [ ] Exclusive lot: browse only, shows USD price + store link
- [ ] Exclusive models cannot be bought with cash
- [ ] Client car packs ensured from `[assets]`: `CyberTruckV`, `cometmans`,
      `sddriftvet`, `ip_m1000rr_23`
- [ ] `hc_tebex_grant <id> CyberTruckV TEST1` delivers while online
- [ ] Same command with the same transaction id a second time is ignored
- [ ] Grant made while the buyer is **offline** arrives on their next login
- [ ] `hc_tebex_pending` lists nothing once deliveries land

Full store wiring and test matrix: [`docs/tebex-setup.md`](tebex-setup.md)

## Clothing (`hc-clothing`)

- [ ] Vinewood, Beach, La Galeria shops open appearance menu
- [ ] Mall MLO streaming (`anarchy_LaGaleriaMall`)

## Deadzone (`hc-zombie`)

The Deadzone is on the client's **Alamo Sea island** (`anarchy_Island`). It used
to point at Cayo Perico, which does not exist on this server's game build —
players were teleported into open ocean. Test all of these in game:

- [ ] Docks gate → you land **on the island, on dry ground** (not in water)
- [ ] Supply crates appear as you approach; searching gives salvage / ammo / bandage
- [ ] Zombies spawn 35–70 m away, chase and attack; more of them with more players
- [ ] "Wave 2" notice after 3 minutes inside; zombies get tougher
- [ ] Walk off the island over a bridge → warned, then dragged back
- [ ] Green extract marker → hold [E] 8 s → paid for salvage + kills (cap $2,500)
- [ ] Die inside → salvage lost, normal death/respawn in the city
- [ ] A second player sees the same zombies; a city player does not
- [ ] `hc_dz_status` (server console) shows players, wave, zombie count

If a crate or extract lands somewhere silly, stand where it should be, run
`/dzpos` (admin), and paste the printed `vec3(...)` into
`hc-zombie/shared/config.lua`.

## Live VPS status
## Live VPS status

Updated during M2 wiring on `216.146.24.79`.

- Heartless M2 resources synced and restarted (`hc-drugs` … `hc-zombie`)
- Stream packs ensured: Island / Cardealer / Galeria / TrapHouse / exclusives / DOMA / Revenant / Ghost
- Exclusive dealership models: `CyberTruckV`, `cometmans`, `sddriftvet` (Tebex grant only via `hc_tebex_grant`)
- Scam dirty payout uses `black_money` (Marked Bills) in ox_inventory
- QB SQL applied: `player_vehicles`, `bank_accounts`, `bank_statements`, apartments/clothing, `inventories`
- All 6 businesses remain **FOR SALE**
- `5s_lib` **cannot start** on current Keymaster key (`You lack the required entitlement`). Client must transfer/link the 5scripts asset to the live cfxk, then uncomment `ensure 5s_lib`
- Optional missing QB resources on this box: `qb-fuel`, `qb-adminmenu` (not required for M2 loops)

### Client join / demo path

1. F8: `connect 216.146.24.79:30120`
2. Create/select character → bank money for public cars / armory
3. Drugs: gather → process → street sell (watch PD chance)
4. Scam shop → buy kit → use → marked bills + cooldown
5. Heist ox_target (store/fleeca/jewelry) → stages → payout
6. Armory: realistic + DOMA / Revenant / Ghost purchase
7. Dealership: public bank buy; exclusive lot browse-only; staff test `hc_tebex_grant <id> CyberTruckV` from console
8. Clothing shops + Galeria MLO; Deadzone enter/extract on Island bucket 66

