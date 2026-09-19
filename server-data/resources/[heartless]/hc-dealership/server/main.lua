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

--- Server-side distance check — you buy at the lot, not from your sofa.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.LotDistance)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'dealer:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

RegisterNetEvent('hc-dealership:server:buyPublic', function(model)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'dealer:buy', 3000) then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if type(model) ~= 'string' then return end

    -- Block buying exclusive models with in-game money.
    if getExclusive(model) then
        reject(src, 'buy-exclusive', 'That vehicle is exclusive — real money only.')
        return
    end

    local veh = getPublic(model)
    if not veh then
        reject(src, 'buy-badmodel')
        return
    end

    if not near(src, Config.PublicLot.coords) then
        reject(src, 'buy-distance', 'You have to be at the lot to buy a car.')
        return
    end

    local plate = HCUniquePlate()
    if not plate then
        exports['hc-core']:Notify(src, 'Could not issue a plate — try again.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('bank', veh.price, 'hc-dealer-public') then
        exports['hc-core']:Notify(src, 'Not enough money in bank.', 'error')
        return
    end

    if not HCGiveVehicle(Player, model, plate) then
        Player.Functions.AddMoney('bank', veh.price, 'hc-dealer-public-refund')
        exports['hc-core']:Notify(src, 'Registration failed — you were refunded.', 'error')
        return
    end

    exports['hc-core']:LogMoney(src, 'hc-dealer-public', -veh.price, ('%s (%s)'):format(model, plate))
    TriggerClientEvent('hc-dealership:client:spawnPurchased', src, model, plate, false)
    exports['hc-core']:Notify(src, ('Purchased %s'):format(veh.label), 'success')
end)
