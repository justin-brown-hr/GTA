local QBCore = exports['qb-core']:GetCoreObject()

local function findWeapon(item, isCustom)
    local list = isCustom and Config.Custom or Config.Realistic
    for _, w in ipairs(list) do
        if w.item == item then return w end
    end
end

RegisterNetEvent('hc-weapons:server:buy', function(item, isCustom)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local w = findWeapon(item, isCustom == true)
    if not w then
        exports['hc-core']:Notify(src, 'Invalid weapon.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('bank', w.price, 'hc-weapons-buy') then
        exports['hc-core']:Notify(src, 'Not enough money.', 'error')
        return
    end

    if exports.ox_inventory:AddItem(src, w.item, 1) then
        exports['hc-core']:Notify(src, ('Purchased %s'):format(w.label), 'success')
    else
        Player.Functions.AddMoney('bank', w.price, 'hc-weapons-refund')
        exports['hc-core']:Notify(src, 'Could not give weapon (register item / weapon meta).', 'error')
    end
end)
