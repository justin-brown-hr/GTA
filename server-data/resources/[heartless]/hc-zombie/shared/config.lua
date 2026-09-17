Config = {}

-- Entry from main city → survival bucket
Config.Entrance = {
    coords = vec3(4890.0, -5736.0, 26.3), -- near Cayo-style coords; adjust to your island/MLO
    label = 'Heartless Deadzone Gate',
}

Config.Exit = {
    coords = vec3(4895.0, -5740.0, 26.3),
    label = 'Extract to City',
}

Config.Bucket = 66 -- dedicated routing bucket for zombie world
Config.ReturnBucket = 0

Config.LootHint = 'Kill infected, loot caches, extract before you die. Rewards return to main RP economy carefully.'
