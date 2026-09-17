Config = {}

-- Custom Heartless strains (register matching items in ox_inventory)
Config.Drugs = {
    {
        id = 'heartless_haze',
        label = 'Heartless Haze',
        gatherItem = 'hh_leaf',
        productItem = 'hh_bag',
        gatherCoords = vec3(2224.0, 5577.0, 53.8),
        processCoords = vec3(1391.7, 3606.0, 38.9),
        sellPriceMin = 120,
        sellPriceMax = 190,
    },
    {
        id = 'cali_crush',
        label = 'Cali Crush',
        gatherItem = 'cc_raw',
        productItem = 'cc_brick',
        gatherCoords = vec3(2433.0, 4969.0, 42.3),
        processCoords = vec3(2433.0, 4969.0, 46.8),
        sellPriceMin = 200,
        sellPriceMax = 320,
    },
    {
        id = 'neon_nip',
        label = 'Neon Nip',
        gatherItem = 'nn_chem',
        productItem = 'nn_vial',
        gatherCoords = vec3(3536.0, 3660.0, 28.1),
        processCoords = vec3(3538.0, 3662.0, 28.1),
        sellPriceMin = 250,
        sellPriceMax = 400,
    },
}

Config.SellPed = {
    model = `g_m_y_mexgang_01`,
    coords = vec4(453.2, -1520.5, 29.0, 90.0),
}
