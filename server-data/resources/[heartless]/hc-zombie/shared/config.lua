Config = {}

-- City-side gate (docks) → island Deadzone bucket
Config.Entrance = {
    coords = vec3(1273.4, -3166.8, 5.9),
    label = 'Heartless Deadzone Gate',
}

Config.Exit = {
    coords = vec3(4895.0, -5740.0, 26.3),
    label = 'Extract to City',
}

Config.DeadzoneSpawn = vec4(4840.8, -5174.6, 2.1, 70.0)
Config.CityReturn = vec4(-1037.8, -2737.9, 20.2, 240.0)

Config.Bucket = 66
Config.ReturnBucket = 0

--[[
  Extract payout is per salvage item handed in, capped per run. It is NOT paid
  for simply triggering the exit — see server/main.lua. Salvage only comes from
  caches, and each cache is on CacheCooldownSeconds per player, so this is the
  ceiling on Deadzone income no matter how fast someone cycles the zone.
]]
Config.SalvagePerLootMin = 180
Config.SalvagePerLootMax = 420
Config.ExtractCashMax = 2500

-- How close you must be to the gate / extraction point for it to work.
Config.GateDistance = 12.0
-- Per-player, per-cache refill time.
Config.CacheCooldownSeconds = 120

Config.ZombieModel = `u_m_y_zombie_01`

Config.Caches = {
    vec3(4890.2, -5736.4, 26.3),
    vec3(4905.1, -5720.8, 26.1),
    vec3(4868.4, -5755.2, 26.4),
    vec3(4918.0, -5748.6, 25.9),
}

Config.ZombieSpawns = {
    vec4(4882.0, -5728.0, 26.3, 180.0),
    vec4(4900.0, -5750.0, 26.3, 90.0),
    vec4(4870.0, -5740.0, 26.3, 0.0),
}

Config.LootHint = 'Kill infected, loot caches, extract before you die. Extract cash is capped so Deadzone does not dump the city economy.'
