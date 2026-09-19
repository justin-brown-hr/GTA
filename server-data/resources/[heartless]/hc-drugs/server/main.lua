local QBCore = exports['qb-core']:GetCoreObject()

local lastGather = {}

local function getDrug(id)
    for _, d in ipairs(Config.Drugs) do
        if d.id == id then return d end
    end
end

local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or 8.0)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'drugs:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

RegisterNetEvent('hc-drugs:server:gather', function(drugId)
    local src = source
    local drug = getDrug(drugId)
    if not drug then return end
    if not near(src, drug.gatherCoords, 10.0) then
        reject(src, 'gather-distance', 'You are not at the grow spot.')
        return
    end
    local now = GetGameTimer and GetGameTimer() or (os.time() * 1000)
    if lastGather[src] and (now - lastGather[src]) < (Config.GatherCooldownMs or 8000) then
        exports['hc-core']:Notify(src, 'Slow down.', 'error')
        return
    end
    lastGather[src] = now
    local ok = exports.ox_inventory:AddItem(src, drug.gatherItem, 1)
    if ok then
        exports['hc-core']:Notify(src, ('Gathered %s'):format(drug.label), 'success')
    else
        exports['hc-core']:Notify(src, 'Could not add item (inventory full or item missing).', 'error')
    end
end)

RegisterNetEvent('hc-drugs:server:process', function(drugId)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'drugs:process', 1500) then return end
    local drug = getDrug(drugId)
    if not drug then return end
    if not near(src, drug.processCoords, 10.0) then
        reject(src, 'process-distance', 'You are not at the lab.')
        return
    end

    local need = Config.ProcessNeed or 1
    local count = exports.ox_inventory:GetItemCount(src, drug.gatherItem)
    if not count or count < need then
        exports['hc-core']:Notify(src, 'You need raw materials.', 'error')
        return
    end

    if exports.ox_inventory:RemoveItem(src, drug.gatherItem, need) then
        exports.ox_inventory:AddItem(src, drug.productItem, 1)
        exports['hc-core']:Notify(src, ('Processed %s'):format(drug.label), 'success')
    end
end)

RegisterNetEvent('hc-drugs:server:sell', function(drugId)
    local src = source
    -- One sale at a time: without this a macro can empty a whole bag in a
    -- single frame and skip every police-alert roll in between.
    if not exports['hc-core']:RateLimit(src, 'drugs:sell', Config.SellCooldownMs) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local drug = getDrug(drugId)
    if not drug then return end
    local c = Config.SellPed.coords
    if not near(src, vec3(c.x, c.y, c.z), 12.0) then
        reject(src, 'sell-distance', 'Buyer is not here.')
        return
    end

    local count = exports.ox_inventory:GetItemCount(src, drug.productItem)
    if not count or count < 1 then
        exports['hc-core']:Notify(src, 'Nothing to sell.', 'error')
        return
    end

    if exports.ox_inventory:RemoveItem(src, drug.productItem, 1) then
        local pay = math.random(drug.sellPriceMin, drug.sellPriceMax)
        local ok, cfg = pcall(function()
            return exports['hc-core']:GetConfig()
        end)
        if ok and cfg and cfg.Economy then
            pay = math.floor(pay * (cfg.Economy.drugSellMultiplier or 1.0))
        end
        Player.Functions.AddMoney('cash', pay, 'hc-drug-sell')
        exports['hc-core']:LogMoney(src, 'hc-drug-sell', pay, drug.productItem)
        exports['hc-core']:Notify(src, ('Sold for $%s'):format(pay), 'success')
        if math.random() < (Config.PdAlertChance or 0.28) then
            exports['hc-core']:AlertPolice(src, '10-15 Possible narcotics sale')
            exports['hc-core']:Notify(src, 'Someone called the cops.', 'error')
        end
    end
end)

AddEventHandler('playerDropped', function()
    lastGather[source] = nil
end)
