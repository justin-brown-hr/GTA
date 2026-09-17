Config = {}

Config.Shop = {
    coords = vec3(22.0, -1107.2, 29.8),
    label = 'Heartless Armory',
}

-- Realistic / vanilla-feel weapons (in-game money)
Config.Realistic = {
    { item = 'WEAPON_PISTOL', label = 'Pistol', price = 3500 },
    { item = 'WEAPON_COMBATPISTOL', label = 'Combat Pistol', price = 5500 },
    { item = 'WEAPON_PUMPSHOTGUN', label = 'Pump Shotgun', price = 12000 },
    { item = 'WEAPON_CARBINERIFLE', label = 'Carbine Rifle', price = 25000 },
}

-- Custom weapons — must be purchased (owner packs); not free
Config.Custom = {
    -- Replace with real custom weapon item names from client packs
    { item = 'WEAPON_HC_CUSTOM1', label = 'HC Custom Sidearm', price = 45000 },
    { item = 'WEAPON_HC_CUSTOM2', label = 'HC Custom Rifle', price = 90000 },
}
