Config = {}

-- In-game cash/bank vehicles
Config.PublicLot = {
    coords = vec3(-56.8, -1096.6, 26.4),
    label = 'Heartless Public Motors',
    vehicles = {
        { model = 'sultan', label = 'Sultan', price = 35000 },
        { model = 'buffalo', label = 'Buffalo', price = 45000 },
        { model = 'sanchez', label = 'Sanchez', price = 12000 },
    },
}

-- Real-money exclusive lot (owner packages via Tebex)
-- Players cannot buy these with in-game money.
Config.ExclusiveLot = {
    coords = vec3(-783.5, -212.5, 37.0),
    label = 'Heartless Exclusive Collection',
    vehicles = {
        -- Replace models with client's exclusive pack spawn names
        { model = 'hc_exclusive1', label = 'Exclusive One', tebexPackageId = 'PKG_EXCLUSIVE_1' },
        { model = 'hc_exclusive2', label = 'Exclusive Two', tebexPackageId = 'PKG_EXCLUSIVE_2' },
        { model = 'hc_exclusive3', label = 'Exclusive Three', tebexPackageId = 'PKG_EXCLUSIVE_3' },
    },
    -- Shown in UI when browsing exclusive lot
    buyHint = 'These vehicles are purchase-only with real money via the Heartless Tebex store.',
}
