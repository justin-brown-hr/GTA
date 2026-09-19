Config = {}

Config.MaxEmployees = 5

-- Server-side guards: how close you must be to the desk / stash, and the
-- ceiling on a single deposit or withdrawal.
Config.InteractDistance = 12.0
Config.MaxTransaction = 5000000
Config.StashSlots = 50
Config.StashWeight = 200000

-- Passive income tick (minutes) while owner is online — simple M1 loop
Config.PassiveIncome = {
    enabled = true,
    intervalMinutes = 30,
    amounts = {
        mechanic = 350,
        bar = 275,
        shop = 200,
        weapons = 400,
    },
}

Config.Businesses = {
    {
        key = 'ls_customs',
        label = 'Heartless Customs',
        price = 250000,
        coords = vec3(-365.5, -131.5, 38.7),
        stashCoords = vec3(-362.8, -128.5, 38.7),
        type = 'mechanic',
    },
    {
        key = 'vinewood_bar',
        label = 'Vinewood Pour House',
        price = 175000,
        coords = vec3(127.8, -1296.0, 29.3),
        stashCoords = vec3(132.5, -1293.8, 29.3),
        type = 'bar',
    },
    {
        key = 'grove_247',
        label = 'Grove 24/7',
        price = 120000,
        coords = vec3(-48.5, -1757.5, 29.4),
        stashCoords = vec3(-43.8, -1755.2, 29.4),
        type = 'shop',
    },
    {
        key = 'mirror_gunlease',
        label = 'Mirror Park Armory Lease',
        price = 300000,
        coords = vec3(842.2, -1033.4, 28.2),
        stashCoords = vec3(846.5, -1035.1, 28.2),
        type = 'weapons',
    },
    {
        key = 'limeys',
        label = 'Limeys Juice',
        price = 90000,
        coords = vec3(-1253.5, -1483.6, 4.3),
        stashCoords = vec3(-1256.2, -1481.1, 4.3),
        type = 'shop',
    },
    {
        key = 'galaxy_club',
        label = 'Galaxy Club',
        price = 400000,
        coords = vec3(-430.1, -23.5, 46.2),
        stashCoords = vec3(-427.0, -21.2, 46.2),
        type = 'bar',
    },
}
