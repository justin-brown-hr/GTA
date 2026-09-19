Config = {}

-- How close you must be to the counter for a purchase to go through.
Config.ShopDistance = 12.0

Config.Shop = {
    coords = vec3(22.0, -1107.2, 29.8),
    label = 'Heartless Armory',
}

--[[
  Realistic / vanilla-feel weapons, bought with in-game money.

  The client's skin packs re-texture these vanilla weapons rather than adding
  new ones, so a player buying a "Pistol" here gets whichever skin pack is
  streaming for WEAPON_PISTOL. Several packs compete for the same slot — the
  collision table in docs/client-assets.md says which ones, and only one can win.
]]
Config.Realistic = {
    { item = 'WEAPON_PISTOL', label = 'Pistol (custom skins stream)', price = 3500 },
    { item = 'WEAPON_COMBATPISTOL', label = 'Combat Pistol', price = 5500 },
    { item = 'WEAPON_APPISTOL', label = 'AP Pistol / Glock 18c style', price = 8500 },
    { item = 'WEAPON_SNSPISTOL', label = 'SNS Pistol', price = 2800 },
    { item = 'WEAPON_PISTOL50', label = 'Pistol .50', price = 9000 },
    { item = 'WEAPON_PUMPSHOTGUN', label = 'Pump Shotgun', price = 12000 },
    { item = 'WEAPON_SMG', label = 'SMG', price = 16000 },
    { item = 'WEAPON_CARBINERIFLE', label = 'Carbine / custom M4 stream', price = 25000 },
    { item = 'WEAPON_ASSAULTRIFLE', label = 'AK-style rifle', price = 28000 },
    { item = 'WEAPON_SPECIALCARBINE', label = 'Special Carbine', price = 32000 },
}

--[[
  Custom addon weapons from the client's packs — real, separate weapons with
  their own WEAPON_ names (not re-skins). Must be purchased; never free.

  Every name here was read out of the pack's own weapons.meta — see
  docs/client-assets.md section A. They must also be registered in
  ox_inventory/data/weapons.lua (database/ox_weapons_heartless.lua) or the
  purchase will fail with "could not give weapon".
]]
Config.Custom = {
    { item = 'WEAPON_DOMA', label = 'UDM DOMA', price = 55000 },
    { item = 'WEAPON_REVENANT15', label = 'Revenant-15', price = 95000 },
    { item = 'WEAPON_GHOST', label = 'Ghost Pistol', price = 48000 },
    { item = 'WEAPON_PRINGLE', label = 'Pringle SMG', price = 62000 },
    { item = 'WEAPON_MITSURISWITCHDRUM', label = 'Mitsuri Switch (drum)', price = 71000 },
    { item = 'WEAPON_TANJIROSWITCHDRUM', label = 'Tanjiro Switch (drum)', price = 71000 },
}
