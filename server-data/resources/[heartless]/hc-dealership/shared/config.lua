Config = {}

-- How close you must actually stand to the lot for a purchase to go through.
Config.LotDistance = 15.0
-- Garage new cars are parked in (must match your qb-garages config).
Config.DefaultGarage = 'pillboxgarage'

-- Wait after a character loads before handing over queued Tebex purchases, so
-- the delivery notify does not land during the spawn/loading screen.
Config.GrantDeliveryDelayMs = 8000

Config.PublicSpawn = vec4(-47.5, -1116.4, 26.4, 70.0)
Config.ExclusiveSpawn = vec4(-791.2, -218.8, 37.1, 210.0)

--[[
  Every vehicle is spawned by the server, which has to be told what kind of
  vehicle it is: `type` = automobile (default) | bike | boat | heli | plane |
  trailer. A wrong type spawns a broken vehicle, so set it on anything that is
  not a car.
]]

-- In-game cash/bank vehicles (vanilla — not client exclusives)
Config.PublicLot = {
    coords = vec3(-56.8, -1096.6, 26.4),
    label = 'Heartless Public Motors',
    vehicles = {
        { model = 'sultan', label = 'Sultan', price = 35000 },
        { model = 'buffalo', label = 'Buffalo', price = 45000 },
        { model = 'sanchez', label = 'Sanchez', price = 12000, type = 'bike' },
        { model = 'faggio', label = 'Faggio', price = 2500, type = 'bike' },
        { model = 'oracle', label = 'Oracle', price = 28000 },
        { model = 'baller', label = 'Baller', price = 52000 },
        { model = 'bison', label = 'Bison', price = 22000 },
        { model = 'sadler', label = 'Sadler', price = 18000 },
        { model = 'seashark', label = 'Seashark', price = 15000, type = 'boat' },
    },
}

--[[
  Real-money exclusive lot. These can never be bought with in-game money.

  Each entry needs:
    model          spawn name from the pack's vehicles.meta (case sensitive)
    label          what players see
    tebexPackageId the package id in your Tebex store — the store command can
                   pass either this or the model
    priceUsd       display only; Tebex is what actually charges

  Adding a car: put the model here, ensure the stream resource in server.cfg,
  create the Tebex package, and point its command at hc_tebex_grant.
  Full walkthrough: docs/tebex-setup.md
]]
Config.ExclusiveLot = {
    coords = vec3(-783.5, -212.5, 37.0),
    label = 'Heartless Exclusive Collection',
    storeUrl = 'https://heartlesscityrp.tebex.io',
    vehicles = {
        { model = 'CyberTruckV', label = 'Cybertruck', tebexPackageId = 'PKG_CYBERTRUCK', priceUsd = 35 },
        { model = 'cometmans', label = 'Comet Mansory', tebexPackageId = 'PKG_COMETMANS', priceUsd = 30 },
        { model = 'sddriftvet', label = 'Drift Corvette', tebexPackageId = 'PKG_DRIFTVET', priceUsd = 25 },
        { model = 'ip_m1000rr_23', label = 'BMW S1000RR 2023', tebexPackageId = 'PKG_S1000RR', priceUsd = 20, type = 'bike' },
        -- Everything below needs its pack converted from a singleplayer add-on
        -- to a FiveM resource before it can be listed. Confirmed spawn names are
        -- in docs/client-assets.md section B — uncomment as each one is built.
        -- { model = 'feno26sx',   label = 'Lamborghini Fenomeno', tebexPackageId = 'PKG_FENOMENO', priceUsd = 40 },
        -- { model = 'ferrarif80', label = 'Ferrari F80',          tebexPackageId = 'PKG_F80',      priceUsd = 40 },
        -- { model = 'g550trg',    label = 'Mercedes G550',        tebexPackageId = 'PKG_G550',     priceUsd = 30 },
        -- { model = 'bubba',      label = 'Brabus G63 10x10',     tebexPackageId = 'PKG_BRABUS',   priceUsd = 35 },
        -- { model = 'audir82023', label = 'Audi R8 2023',         tebexPackageId = 'PKG_R8',       priceUsd = 30 },
    },
    buyHint = 'Exclusive collection — real money only, through the Heartless store. Your car is delivered to your garage automatically, even if you buy while offline.',
}
