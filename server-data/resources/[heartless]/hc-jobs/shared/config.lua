Config = {}

Config.JobCenter = {
    coords = vec3(-265.0, -963.6, 31.2),
    label = 'Heartless Job Center',
}

Config.StopsPerRun = 3
Config.ProgressMs = 5000

--[[
  Each job:
  - vehicle: spawn model at depot (nil = on foot)
  - depot: where work vehicle spawns / job starts in world
  - stops: delivery / collect points
  - returnToDepot: must return vehicle before payday
]]
Config.Jobs = {
    {
        id = 'delivery',
        label = 'Package Delivery',
        payMin = 120,
        payMax = 200,
        description = 'Pick up packages and deliver across the city.',
        vehicle = 'boxville2',
        depot = vec4(118.3, -107.2, 60.5, 160.0),
        returnToDepot = true,
        stops = {
            vec3(215.1, -810.1, 30.7),
            vec3(-702.2, -916.8, 19.2),
            vec3(1130.5, -982.3, 46.4),
            vec3(-47.5, -1757.8, 29.4),
            vec3(373.9, 326.8, 103.6),
            vec3(-1222.9, -907.2, 12.3),
        },
    },
    {
        id = 'tow',
        label = 'Tow Driver',
        payMin = 140,
        payMax = 240,
        description = 'Tow stranded vehicles back to the yard.',
        vehicle = 'towtruck',
        depot = vec4(408.9, -1623.5, 29.3, 230.0),
        returnToDepot = true,
        -- stops act as broken-car locations (we simulate attach + return)
        stops = {
            vec3(215.8, -1389.5, 30.6),
            vec3(-339.2, -136.8, 39.0),
            vec3(1205.2, -1389.8, 35.2),
            vec3(-1154.3, -1425.6, 4.7),
            vec3(822.5, -2138.2, 29.3),
        },
    },
    {
        id = 'fishing',
        label = 'Fishing',
        payMin = 90,
        payMax = 160,
        description = 'Fish at the pier, then sell your catch.',
        vehicle = nil,
        depot = vec4(-1850.2, -1249.6, 8.6, 140.0),
        returnToDepot = false,
        sellCoords = vec3(-1816.5, -1193.8, 14.3),
        stops = {
            vec3(-1850.5, -1248.8, 8.6),
            vec3(-1855.2, -1241.1, 8.6),
            vec3(-1844.8, -1255.4, 8.6),
            vec3(-1862.0, -1235.0, 8.6),
        },
    },
    {
        id = 'mining',
        label = 'Mining',
        payMin = 130,
        payMax = 210,
        description = 'Mine ore in the hills and turn it in.',
        vehicle = nil,
        depot = vec4(2952.1, 2788.9, 41.5, 200.0),
        returnToDepot = false,
        sellCoords = vec3(2954.2, 2744.5, 43.6),
        stops = {
            vec3(2945.8, 2794.2, 40.8),
            vec3(2938.1, 2802.5, 41.2),
            vec3(2925.4, 2790.1, 41.0),
            vec3(2960.2, 2805.8, 41.5),
        },
    },
    {
        id = 'taxi',
        label = 'Taxi Driver',
        payMin = 100,
        payMax = 190,
        description = 'Pick up NPC fares around Los Santos.',
        vehicle = 'taxi',
        depot = vec4(909.5, -177.8, 74.2, 240.0),
        returnToDepot = true,
        stops = {
            vec3(295.3, -590.2, 43.3),
            vec3(-1037.8, -2737.9, 20.2),
            vec3(185.2, -915.8, 30.7),
            vec3(-526.4, -234.5, 36.2),
            vec3(920.1, 48.5, 80.9),
            vec3(-1370.5, -475.8, 31.6),
        },
    },
    {
        id = 'garbage',
        label = 'Sanitation',
        payMin = 110,
        payMax = 185,
        description = 'Collect trash bins on your route.',
        vehicle = 'trash2',
        depot = vec4(-322.2, -1545.8, 31.0, 270.0),
        returnToDepot = true,
        stops = {
            vec3(-350.5, -1556.2, 25.2),
            vec3(-45.8, -1755.2, 29.4),
            vec3(115.2, -1953.5, 20.8),
            vec3(289.5, -1266.8, 29.3),
            vec3(-702.5, -930.2, 19.0),
            vec3(1224.8, -1400.5, 35.0),
        },
    },
}
