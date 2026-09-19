Config = {}

--[[
  THE DEADZONE

  An instanced survival zone on the client's Alamo Sea island map
  (anarchy_Island / turbosaif_alamo_island). Players enter through a gate in
  the city, are moved into their own routing bucket, and fight server-spawned
  zombies for salvage they must carry out alive.

  Location note: this used to point at Cayo Perico (4840, -5174). Cayo Perico
  does not exist on the game build this server runs, so players were being
  teleported into open ocean. The island coordinates below come from the map
  pack's own .ymap extents (x -6..527, y 3772..4205).

  Positions are x/y first. Ground height is resolved in game at runtime (the
  `z` values are only hints), and any point that turns out to be water is
  nudged to the nearest dry land — so a slightly-off coordinate degrades to
  "a few metres away", never "underwater". Staff can tune points in game with
  /dzpos, which prints the exact coords to paste here.
]]

-- City-side gate (docks) → Deadzone
Config.Entrance = {
    coords = vec3(1273.4, -3166.8, 5.9),
    label = 'Heartless Deadzone Gate',
}

-- Where players land and where they are returned to.
Config.Arrival = vec4(262.0, 3890.0, 40.0, 90.0)
Config.CityReturn = vec4(1270.2, -3160.4, 5.9, 90.0)

-- The zone itself. Players who wander past the radius are warned, then pulled
-- back to the arrival point — nobody walks out of an instance into the city.
Config.Zone = {
    center = vec3(262.0, 3990.0, 30.0),
    radius = 320.0,
    label = 'HC Deadzone',
}

-- Extraction points. Standing at one and holding the prompt carries salvage out.
Config.Extracts = {
    vec3(142.0, 3905.0, 32.0),
    vec3(405.0, 4085.0, 32.0),
}
Config.ExtractSeconds = 8        -- how long you must hold still at the point
Config.GateDistance = 12.0       -- city gate radius (server-checked)

-- Crates and extract points are placed on the nearest dry ground within
-- SnapRadius of their configured x/y. The server accepts interactions within
-- PointTolerance of the configured point, so it must stay larger than
-- SnapRadius plus the few metres you stand away from a crate.
Config.SnapRadius = 18.0
Config.PointTolerance = 24.0

Config.Bucket = 66
Config.ReturnBucket = 0

--[[ Loot ---------------------------------------------------------------- ]]

Config.Caches = {
    vec3(190.0, 3950.0, 32.0),
    vec3(330.0, 3920.0, 32.0),
    vec3(380.0, 4060.0, 32.0),
    vec3(260.0, 4110.0, 32.0),
    vec3(300.0, 4000.0, 32.0),
    vec3(215.0, 4050.0, 32.0),
}
Config.CacheCooldownSeconds = 150
Config.CacheProp = `prop_mil_crate_01`

-- Weighted cache loot. `hc_dz_loot` is what pays out at extraction.
Config.LootTable = {
    { item = 'hc_dz_loot', min = 1, max = 2, weight = 70 },
    { item = 'ammo-9', min = 12, max = 24, weight = 15 },
    { item = 'bandage', min = 1, max = 1, weight = 15 },
}

--[[
  Extract payout is per salvage item handed in, plus a bonus per zombie the
  server saw you kill, capped per run. Nothing is paid for simply leaving.
  Die inside and you drop everything you were carrying.
]]
Config.SalvagePerLootMin = 180
Config.SalvagePerLootMax = 420
Config.KillBonus = 25
Config.ExtractCashMax = 2500

--[[ Zombies ------------------------------------------------------------- ]]

Config.ZombieModels = {
    `u_m_y_zombie_01`,
    `a_m_m_tramp_01`,
    `a_m_m_hillbilly_01`,
    `a_m_o_acult_02`,
    `a_f_m_tramp_01`,
    `a_m_m_skidrow_01`,
}

--[[
  The server "director" keeps a population around the players inside:
      target = BasePerPlayer * players + WaveBonus * (wave - 1)
  capped at MaxAlive. The wave rises every WaveMinutes while anyone is inside
  and resets when the zone empties.
]]
Config.Director = {
    tickSeconds = 3,
    basePerPlayer = 5,
    waveBonus = 2,
    waveMinutes = 3,
    maxWave = 5,
    maxAlive = 30,
    spawnMinDistance = 35.0,
    spawnMaxDistance = 70.0,
    despawnDistance = 160.0,    -- zombies this far from every player are culled
    corpseSeconds = 20,         -- how long bodies stay before cleanup
}

-- Per-wave toughness, applied by the client that first takes ownership.
Config.ZombieHealth = 200
Config.ZombieHealthPerWave = 40
