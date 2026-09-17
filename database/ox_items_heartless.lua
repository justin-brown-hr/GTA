-- Merge these into ox_inventory/data/items.lua (or your items definition file)

return {
    ['hh_leaf'] = { label = 'Heartless Haze Leaf', weight = 50, stack = true, close = true },
    ['hh_bag'] = { label = 'Heartless Haze Bag', weight = 80, stack = true, close = true },
    ['cc_raw'] = { label = 'Cali Crush Raw', weight = 60, stack = true, close = true },
    ['cc_brick'] = { label = 'Cali Crush Brick', weight = 200, stack = true, close = true },
    ['nn_chem'] = { label = 'Neon Nip Chem', weight = 40, stack = true, close = true },
    ['nn_vial'] = { label = 'Neon Nip Vial', weight = 70, stack = true, close = true },

    ['hc_skimmer'] = { label = 'Card Skimmer', weight = 500, stack = false, close = true },
    ['hc_spoofphone'] = { label = 'Spoof Phone', weight = 300, stack = false, close = true },
    ['hc_clonekit'] = { label = 'Clone Kit', weight = 800, stack = false, close = true },
    ['hc_signaljammer'] = { label = 'Signal Jammer', weight = 1000, stack = false, close = true },
}
