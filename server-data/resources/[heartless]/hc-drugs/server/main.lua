local QBCore = exports['qb-core']:GetCoreObject()

local function getDrug(id)
    for _, d in ipairs(Config.Drugs) do
        if d.id == id then return d end
    end
end

RegisterNetEvent('hc-drugs:server:gather', function(drugId)
    local src = source
    local drug = getDrug(drugId)
    if not drug then return end

    local ok = exports.ox_inventory:AddItem(src, drug.gatherItem, 1)
    if ok then
        exports['hc-core']:Notify(src, ('Gathered %s'):format(drug.label), 'success')
    else
        exports['hc-core']:Notify(src, 'Could not add item (inventory full or item missing).', 'error')
    end
end)

RegisterNetEvent('hc-drugs:server:process', function(drugId)
    local src = source
    local drug = getDrug(drugId)
    if not drug then return end

    local count = exports.ox_inventory:GetItemCount(src, drug.gatherItem)
    if not count or count < 1 then
        exports['hc-core']:Notify(src, 'You need raw materials.', 'error')
        return
    end

    if exports.ox_inventory:RemoveItem(src, drug.gatherItem, 1) then
        exports.ox_inventory:AddItem(src, drug.productItem, 1)
        exports['hc-core']:Notify(src, ('Processed %s'):format(drug.label), 'success')
    end
end)

RegisterNetEvent('hc-drugs:server:sell', function(drugId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local drug = getDrug(drugId)
    if not drug then return end

    local count = exports.ox_inventory:GetItemCount(src, drug.productItem)
    if not count or count < 1 then
        exports['hc-core']:Notify(src, 'Nothing to sell.', 'error')
        return
    end

    if exports.ox_inventory:RemoveItem(src, drug.productItem, 1) then
        local pay = math.random(drug.sellPriceMin, drug.sellPriceMax)
        Player.Functions.AddMoney('cash', pay, 'hc-drug-sell')
        exports['hc-core']:Notify(src, ('Sold for $%s'):format(pay), 'success')
        -- TODO: chance to alert PD
    end
end)
