local QBCore = exports['qb-core']:GetCoreObject()

--- Server-side distance check.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.ShopDistance)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'scam:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

local busy = {}

local function getEquip(item)
    for _, eq in ipairs(Config.Equipment) do
        if eq.item == item then return eq end
    end
end

RegisterNetEvent('hc-scam:server:buy', function(item)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'scam:buy', 2000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local eq = getEquip(item)
    if not eq then
        reject(src, 'buy-baditem')
        return
    end
    if not near(src, Config.Shop.coords) then
        reject(src, 'buy-distance', 'The dealer is not here.')
        return
    end

    if not Player.Functions.RemoveMoney('cash', eq.price, 'hc-scam-buy') then
        exports['hc-core']:Notify(src, 'Not enough cash.', 'error')
        return
    end

    if exports.ox_inventory:AddItem(src, eq.item, 1) then
        exports['hc-core']:LogMoney(src, 'hc-scam-buy', -eq.price, eq.item)
        exports['hc-core']:Notify(src, ('Purchased %s'):format(eq.label), 'success')
    else
        Player.Functions.AddMoney('cash', eq.price, 'hc-scam-refund')
        exports['hc-core']:Notify(src, 'Purchase failed — item not registered?', 'error')
    end
end)

local function beginUse(src, item)
    if not exports['hc-core']:RateLimit(src, 'scam:use', 2000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local eq = getEquip(item)
    if not eq then return end
    if busy[src] then
        exports['hc-core']:Notify(src, 'Already using a tool.', 'error')
        return
    end

    local row = MySQL.single.await(
        'SELECT expires_at FROM hc_scam_cooldowns WHERE citizenid = ? AND item = ? AND expires_at > NOW() LIMIT 1',
        { Player.PlayerData.citizenid, item }
    )
    if row then
        exports['hc-core']:Notify(src, 'That kit is still cooling down.', 'error')
        return
    end

    if (exports.ox_inventory:GetItemCount(src, item) or 0) < 1 then
        exports['hc-core']:Notify(src, 'You do not have that kit.', 'error')
        return
    end

    busy[src] = item
    TriggerClientEvent('hc-scam:client:used', src, eq.label)
    TriggerClientEvent('hc-scam:client:runUse', src, item, eq.label)
end

RegisterNetEvent('hc-scam:server:use', function(data)
    local item = data
    if type(data) == 'table' then
        item = data.name or data.item
    end
    beginUse(source, item)
end)

RegisterNetEvent('hc-scam:server:finishUse', function(item, success)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local pending = busy[src]
    busy[src] = nil
    if not Player or pending ~= item then return end
    local eq = getEquip(item)
    if not eq then return end

    if not success then
        exports['hc-core']:Notify(src, 'You stopped.', 'error')
        return
    end

    MySQL.query.await(
        [[INSERT INTO hc_scam_cooldowns (citizenid, item, expires_at)
          VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
          ON DUPLICATE KEY UPDATE expires_at = VALUES(expires_at)]],
        { Player.PlayerData.citizenid, item, eq.cooldownMinutes }
    )

    local pay = math.random(Config.PayoutMin, Config.PayoutMax)
    -- Dirty payout: marked bills item if registered, else cash
    local paidDirty = exports.ox_inventory:AddItem(src, 'black_money', pay)
    if not paidDirty then
        Player.Functions.AddMoney('cash', pay, 'hc-scam-use')
    end
    exports['hc-core']:LogMoney(src, 'hc-scam-use', pay, item)
    exports['hc-core']:Notify(src, ('The play paid $%s — keep a low profile.'):format(pay), 'success')

    if math.random() < (Config.PdAlertChance or 0.35) then
        exports['hc-core']:AlertPolice(src, '10-90 Possible fraud / skimmer activity')
        exports['hc-core']:Notify(src, 'Heat is on you.', 'error')
    end
end)

AddEventHandler('ox_inventory:usedItem', function(playerId, name)
    if getEquip(name) then
        beginUse(playerId, name)
    end
end)

AddEventHandler('playerDropped', function()
    busy[source] = nil
end)
