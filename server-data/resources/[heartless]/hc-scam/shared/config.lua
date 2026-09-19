Config = {}

-- How close you must be to the black-market dealer to buy.
Config.ShopDistance = 12.0

Config.Shop = {
    coords = vec3(1272.0, -1711.5, 54.8),
    label = 'Black Market Tools',
}

Config.PdAlertChance = 0.35
Config.PayoutMin = 400
Config.PayoutMax = 900

-- Equipment players buy then use (progress + risk + cooldown)
Config.Equipment = {
    { item = 'hc_skimmer', label = 'Card Skimmer', price = 2500, cooldownMinutes = 30 },
    { item = 'hc_spoofphone', label = 'Spoof Phone', price = 4000, cooldownMinutes = 45 },
    { item = 'hc_clonekit', label = 'Clone Kit', price = 6500, cooldownMinutes = 60 },
    { item = 'hc_signaljammer', label = 'Signal Jammer', price = 8000, cooldownMinutes = 90 },
}
