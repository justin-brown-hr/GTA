local QBCore = exports['qb-core']:GetCoreObject()

--- [src] = { enteredAt = os.time() }  — set only by a validated enter
local inside = {}
local lootCd = {}

--- Server-side distance check. The client may ask; the server decides.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or 8.0)
end

local function rateLimit(src, key, ms)
    return exports['hc-core']:RateLimit(src, key, ms)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'zombie:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

RegisterNetEvent('hc-zombie:server:enter', function()
    local src = source
    if not rateLimit(src, 'zombie:enter', 3000) then return end
    if not QBCore.Functions.GetPlayer(src) then return end

    if inside[src] then
        exports['hc-core']:Notify(src, 'You are already in the Deadzone.', 'error')
        return
    end

    if not near(src, Config.Entrance.coords, Config.GateDistance) then
        reject(src, 'enter-distance', 'You are not at the Deadzone gate.')
        return
    end

    inside[src] = { enteredAt = os.time() }
    SetPlayerRoutingBucket(src, Config.Bucket)
    TriggerClientEvent('hc-zombie:client:entered', src)
    exports['hc-core']:Notify(src, 'Entered the Deadzone.', 'warning')
end)

RegisterNetEvent('hc-zombie:server:loot', function(index)
    local src = source
    if not rateLimit(src, 'zombie:loot', 2000) then return end
    if not inside[src] then
        reject(src, 'loot-outside')
        return
    end
    if not QBCore.Functions.GetPlayer(src) then return end

    index = tonumber(index)
    local coords = index and Config.Caches[index]
    if not coords then
        reject(src, 'loot-badindex')
        return
    end
    if not near(src, coords, 8.0) then
        reject(src, 'loot-distance', 'You are not at that cache.')
        return
    end

    local key = src .. ':' .. index
    local now = os.time()
    if lootCd[key] and (now - lootCd[key]) < Config.CacheCooldownSeconds then
        exports['hc-core']:Notify(src, 'Already picked this cache clean.', 'error')
        return
    end
    lootCd[key] = now

    if exports.ox_inventory:AddItem(src, 'hc_dz_loot', 1) then
        exports['hc-core']:Notify(src, 'You stuffed salvage in your bag.', 'success')
    else
        lootCd[key] = nil
        exports['hc-core']:Notify(src, 'Your bag is full.', 'error')
    end
end)

--- Move a player back to the city. Always safe to call — never leaves someone
--- stranded in bucket 66 just because a payout was denied.
local function sendToCity(src)
    inside[src] = nil
    SetPlayerRoutingBucket(src, Config.ReturnBucket)
    TriggerClientEvent('hc-zombie:client:extracted', src)
end

RegisterNetEvent('hc-zombie:server:exit', function()
    local src = source
    if not rateLimit(src, 'zombie:exit', 3000) then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local session = inside[src]
    if not session then
        -- This is the event that used to pay out unconditionally. Anyone who
        -- reaches this branch is either desynced or fishing for free cash.
        reject(src, 'exit-not-inside', 'You are not in the Deadzone.')
        SetPlayerRoutingBucket(src, Config.ReturnBucket)
        return
    end

    if not near(src, Config.Exit.coords, Config.GateDistance) then
        reject(src, 'exit-distance', 'Get to the extraction point first.')
        return
    end

    -- Payout is tied to salvage you actually carry out, not to the act of
    -- leaving. Salvage comes from caches, which are on a per-cache cooldown,
    -- so there is no way to farm this faster than the caches refill.
    local carried = exports.ox_inventory:GetItemCount(src, 'hc_dz_loot') or 0
    sendToCity(src)

    if carried < 1 then
        exports['hc-core']:Notify(src, 'Extracted empty-handed — no salvage, no payout.', 'inform')
        return
    end

    if not exports.ox_inventory:RemoveItem(src, 'hc_dz_loot', carried) then
        exports['hc-core']:Notify(src, 'Could not hand in your salvage — keep it and try again.', 'error')
        return
    end

    local pay = 0
    for _ = 1, carried do
        pay = pay + math.random(Config.SalvagePerLootMin, Config.SalvagePerLootMax)
    end
    pay = math.min(pay, Config.ExtractCashMax)

    Player.Functions.AddMoney('cash', pay, 'hc-deadzone-extract')
    exports['hc-core']:LogMoney(src, 'hc-deadzone-extract', pay, ('%s salvage'):format(carried))
    exports['hc-core']:Notify(src, ('Extracted with %s salvage. Paid $%s'):format(carried, pay), 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    inside[src] = nil
    for key in pairs(lootCd) do
        if key:sub(1, #tostring(src) + 1) == src .. ':' then
            lootCd[key] = nil
        end
    end
    SetPlayerRoutingBucket(src, Config.ReturnBucket)
end)
