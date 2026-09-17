local QBCore = exports['qb-core']:GetCoreObject()

local function getEquip(item)
    for _, eq in ipairs(Config.Equipment) do
        if eq.item == item then return eq end
    end
end

RegisterNetEvent('hc-scam:server:buy', function(item)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local eq = getEquip(item)
    if not eq then return end

    if not Player.Functions.RemoveMoney('cash', eq.price, 'hc-scam-buy') then
        exports['hc-core']:Notify(src, 'Not enough cash.', 'error')
        return
    end

    if exports.ox_inventory:AddItem(src, eq.item, 1) then
        exports['hc-core']:Notify(src, ('Purchased %s'):format(eq.label), 'success')
    else
        Player.Functions.AddMoney('cash', eq.price, 'hc-scam-refund')
        exports['hc-core']:Notify(src, 'Purchase failed — item not registered?', 'error')
    end
end)

-- Scaffold: full scam minigames + PD alerts in next iteration
RegisterNetEvent('hc-scam:server:use', function(item)
    local src = source
    local eq = getEquip(item)
    if not eq then return end
    TriggerClientEvent('hc-scam:client:used', src, eq.label)
end)
