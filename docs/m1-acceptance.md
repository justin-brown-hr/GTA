# Milestone 1 — Acceptance checklist

Use this with the client on staging.

## Setup (you / hosting)

- [ ] FXServer running with QBCore + oxmysql + ox_lib + ox_inventory + ox_target + pma-voice
- [ ] `database/schema.sql` imported
- [ ] `server.cfg` ensures `hc-core`, `hc-jobs`, `hc-business`
- [ ] Player can join, create character, move, use inventory & voice

## Jobs (`hc-jobs`)

- [ ] Job Center blip near Legion / city hall area opens menu
- [ ] Each job starts: delivery, tow, fishing, mining, taxi, garbage
- [ ] Work vehicles spawn for driving jobs
- [ ] GPS route to stops; **E** completes stop with progress bar
- [ ] After stops: return vehicle or sell/turn-in where required
- [ ] Cash paid once per run; cannot spam complete
- [ ] `/canceljob` or Job Center cancel clears duty

## Businesses (`hc-business`)

- [ ] 4 businesses show on map with desk target
- [ ] Unowned business can be bought with bank money
- [ ] Owner can deposit / withdraw
- [ ] Owner can hire / fire by server ID
- [ ] Owner & employees can open business stash
- [ ] Owner can sell business (50% + balance refund)
- [ ] Passive income ticks into business balance while enabled

## Branding

- [ ] `/hcinfo` and `/hcdiscord` work
- [ ] Welcome notify shows Discord invite

## Sign-off

| Role | Name | Date | OK |
|------|------|------|----|
| Freelancer | | | |
| Client | | | |
