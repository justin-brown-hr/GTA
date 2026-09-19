Config = {}

-- Set true on live city when PD is staffed
Config.RequireCops = false
Config.PdAlertOnStart = true
Config.LootTimeMs = 7000
Config.MinSecondsPerLoot = 4
-- How close you must be to startCoords to trigger the heist.
Config.StartDistance = 15.0

Config.Heists = {
    {
        key = 'store',
        label = '24/7 Hit',
        minCops = 0,
        cooldownMinutes = 45,
        payoutMin = 2500,
        payoutMax = 4500,
        startCoords = vec3(28.2, -1339.3, 29.5),
        loots = {
            vec3(28.4, -1338.8, 29.5),
            vec3(24.5, -1345.2, 29.5),
            vec3(31.1, -1345.4, 29.5),
        },
    },
    {
        key = 'fleeca',
        label = 'Fleeca Bank',
        minCops = 2,
        cooldownMinutes = 90,
        payoutMin = 12000,
        payoutMax = 18000,
        startCoords = vec3(147.2, -1045.0, 29.4),
        loots = {
            vec3(147.5, -1046.2, 29.4),
            vec3(150.2, -1041.8, 29.4),
            vec3(145.8, -1041.5, 29.4),
        },
    },
    {
        key = 'jewelry',
        label = 'Vangelico',
        minCops = 3,
        cooldownMinutes = 120,
        payoutMin = 20000,
        payoutMax = 32000,
        startCoords = vec3(-631.4, -237.7, 38.1),
        loots = {
            vec3(-626.8, -239.0, 38.1),
            vec3(-620.2, -234.5, 38.1),
            vec3(-617.4, -229.1, 38.1),
            vec3(-623.1, -227.4, 38.1),
        },
    },
}
