local QBCore = exports['qb-core']:GetCoreObject()

local function getPublic(model)
    for _, v in ipairs(Config.PublicLot.vehicles) do
        if v.model == model then return v end
    end
end

local function getExclusive(model)
    for _, v in ipairs(Config.ExclusiveLot.vehicles) do
        if v.model == model then return v end
    end
end

local function randomPlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local plate = 'HC'
    for _ = 1, 6 do
        local i = math.random(#chars)
        plate = plate .. chars:sub(i, i)
    end
    return plate
end

RegisterNetEvent('hc-dealership:server:buyPublic', function(model)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local veh = getPublic(model)
    if not veh then return end

    -- Block buying exclusive models with in-game money
    if getExclusive(model) then
        exports['hc-core']:Notify(src, 'That vehicle is exclusive — real money only.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('bank', veh.price, 'hc-dealer-public') then
        exports['hc-core']:Notify(src, 'Not enough money in bank.', 'error')
        return
    end

    local plate = randomPlate()
    -- Integrate with your garage table (qb-vehicles / player_vehicles)
    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            model,
            joaat(model),
            '{}',
            plate,
            'pillboxgarage',
            0,
        }
    )
    TriggerClientEvent('hc-dealership:client:spawnPurchased', src, model, plate)
    exports['hc-core']:Notify(src, ('Purchased %s'):format(veh.label), 'success')
end)

--- Called by Tebex game server commands / webhook bridge
--- Example command from Tebex: hc_tebex_grant {id} hc_exclusive1
RegisterCommand('hc_tebex_grant', function(source, args)
    if source ~= 0 then return end -- console / tebex only
    local citizenOrServerId = args[1]
    local model = args[2]
    if not citizenOrServerId or not model then
        print('[hc-dealership] Usage: hc_tebex_grant <serverId|citizenid> <model>')
        return
    end

    local exclusive = getExclusive(model)
    if not exclusive then
        print('[hc-dealership] Model not in exclusive list: ' .. tostring(model))
        return
    end

    local Player
    local sid = tonumber(citizenOrServerId)
    if sid then
        Player = QBCore.Functions.GetPlayer(sid)
    else
        Player = QBCore.Functions.GetPlayerByCitizenId(citizenOrServerId)
    end
    if not Player then
        print('[hc-dealership] Player not online for grant')
        return
    end

    local plate = randomPlate()
    local txId = ('tebex-%s-%s'):format(model, os.time())
    MySQL.insert.await(
        'INSERT INTO hc_tebex_grants (transaction_id, citizenid, model, plate) VALUES (?, ?, ?, ?)',
        { txId, Player.PlayerData.citizenid, model, plate }
    )
    MySQL.insert.await(
        'INSERT INTO player_vehicles (license, citizenid, vehicle, hash, mods, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {
            Player.PlayerData.license,
            Player.PlayerData.citizenid,
            model,
            joaat(model),
            '{}',
            plate,
            'pillboxgarage',
            0,
        }
    )
    TriggerClientEvent('hc-dealership:client:spawnPurchased', Player.PlayerData.source, model, plate)
    exports['hc-core']:Notify(Player.PlayerData.source, ('Exclusive vehicle granted: %s'):format(exclusive.label), 'success')
end, true)
