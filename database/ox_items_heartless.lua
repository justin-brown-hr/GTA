-- Merge these into ox_inventory/data/items.lua (or your items definition file)

return {
    ['hh_leaf'] = { label = 'Heartless Haze Leaf', weight = 50, stack = true, close = true },
    ['hh_bag'] = { label = 'Heartless Haze Bag', weight = 80, stack = true, close = true },
    ['cc_raw'] = { label = 'Cali Crush Raw', weight = 60, stack = true, close = true },
    ['cc_brick'] = { label = 'Cali Crush Brick', weight = 200, stack = true, close = true },
    ['nn_chem'] = { label = 'Neon Nip Chem', weight = 40, stack = true, close = true },
    ['nn_vial'] = { label = 'Neon Nip Vial', weight = 70, stack = true, close = true },

    ['hc_skimmer'] = { label = 'Card Skimmer', weight = 500, stack = false, close = true, consume = 0, server = { event = 'hc-scam:server:use' } },
    ['hc_spoofphone'] = { label = 'Spoof Phone', weight = 300, stack = false, close = true, consume = 0, server = { event = 'hc-scam:server:use' } },
    ['hc_clonekit'] = { label = 'Clone Kit', weight = 800, stack = false, close = true, consume = 0, server = { event = 'hc-scam:server:use' } },
    ['hc_signaljammer'] = { label = 'Signal Jammer', weight = 1000, stack = false, close = true, consume = 0, server = { event = 'hc-scam:server:use' } },

    ['hc_heist_bag'] = { label = 'Heist Take', weight = 500, stack = true, close = true },
    ['hc_dz_loot'] = { label = 'Deadzone Salvage', weight = 250, stack = true, close = true },
    ['black_money'] = { label = 'Marked Bills', weight = 0, stack = true, close = true },
}

--[[
  The addon weapons do NOT belong in this file.

  ox_inventory keeps weapons in `ox_inventory/data/weapons.lua`, not in
  `items.lua` — a weapon defined here is not a usable weapon and hc-weapons will
  fail its purchase with "could not give weapon".

  Merge database/ox_weapons_heartless.lua into that file instead.
]]
