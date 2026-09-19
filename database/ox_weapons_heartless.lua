--[[
  Heartless City addon weapons for ox_inventory.

  Merge these into the `Weapons` table in `ox_inventory/data/weapons.lua`
  (NOT items.lua — ox_inventory keeps weapons in their own file, and a weapon
  registered as an item cannot be equipped).

  Every WEAPON_ name here was read out of its pack's own weapons.meta and is
  confirmed — see docs/client-assets.md section A. The matching stream resource
  must also be ensured in server.cfg or the weapon will be invisible in hand.

  Prices and shop placement live in hc-weapons/shared/config.lua.
]]

return {
    -- UDM DOMA — resource hc_wep_doma
    ['WEAPON_DOMA'] = {
        label = 'UDM DOMA',
        weight = 1800,
        durability = 0.1,
        ammoname = 'ammo-9',
    },

    -- Revenant-15 — resource hc_wep_revenant15
    -- NOTE: this pack also replaces the vanilla carbine's model.
    ['WEAPON_REVENANT15'] = {
        label = 'Revenant-15',
        weight = 3200,
        durability = 0.03,
        ammoname = 'ammo-rifle',
    },

    -- Police Ghost — resource hc_wep_ghost
    -- NOTE: this pack also replaces the vanilla pistol's model.
    ['WEAPON_GHOST'] = {
        label = 'Ghost Pistol',
        weight = 1400,
        durability = 0.1,
        ammoname = 'ammo-9',
    },

    -- Pringle SMG — resource hc_wep_pringle
    ['WEAPON_PRINGLE'] = {
        label = 'Pringle SMG',
        weight = 2400,
        durability = 0.05,
        ammoname = 'ammo-9',
    },

    -- Demon Slayer switch Glocks — resources hc_wep_mitsuri / hc_wep_tanjiro
    ['WEAPON_MITSURISWITCHDRUM'] = {
        label = 'Mitsuri Switch (drum)',
        weight = 1600,
        durability = 0.1,
        ammoname = 'ammo-9',
    },
    ['WEAPON_TANJIROSWITCHDRUM'] = {
        label = 'Tanjiro Switch (drum)',
        weight = 1600,
        durability = 0.1,
        ammoname = 'ammo-9',
    },
}
