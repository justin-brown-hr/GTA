local QBCore = exports['qb-core']:GetCoreObject()

--- Server-side distance check.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.ShopDistance)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'weapons:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

local function findWeapon(item, isCustom)
    local list = isCustom and Config.Custom or Config.Realistic
    for _, w in ipairs(list) do
        if w.item == item then return w end
    end
end

RegisterNetEvent('hc-weapons:server:buy', function(item, isCustom)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'weapons:buy', 2000) then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local w = findWeapon(item, isCustom == true)
    if not w then
        reject(src, 'buy-badweapon', 'Invalid weapon.')
        return
    end

    -- Guns are sold over a counter. Without this, any client can buy a rifle
    -- from inside a cell, a hospital bed, or the middle of a shootout.
    if not near(src, Config.Shop.coords) then
        reject(src, 'buy-distance', 'You are not at the armory.')
        return
    end

    if not Player.Functions.RemoveMoney('bank', w.price, 'hc-weapons-buy') then
        exports['hc-core']:Notify(src, 'Not enough money.', 'error')
        return
    end

    if exports.ox_inventory:AddItem(src, w.item, 1) then
        exports['hc-core']:LogMoney(src, 'hc-weapons-buy', -w.price, w.item)
        exports['hc-core']:Notify(src, ('Purchased %s'):format(w.label), 'success')
    else
        Player.Functions.AddMoney('bank', w.price, 'hc-weapons-refund')
        exports['hc-core']:Notify(src, 'Could not give weapon (register item / weapon meta).', 'error')
    end
end)
