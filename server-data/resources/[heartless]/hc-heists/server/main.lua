local QBCore = exports['qb-core']:GetCoreObject()

--- [src] = { key, startedAt, loots = { [i]=true }, paid }
local sessions = {}

local function getHeist(key)
    for _, h in ipairs(Config.Heists) do
        if h.key == key then return h end
    end
end

--- Server-side distance check.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.StartDistance)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'heists:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

local function copsOnDuty()
    local count = 0
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(playerId)
        if P and P.PlayerData.job and P.PlayerData.job.name == 'police' and P.PlayerData.job.onduty then
            count = count + 1
        end
    end
    return count
end

RegisterNetEvent('hc-heists:server:start', function(key)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'heists:start', 5000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local heist = getHeist(key)
    if not heist then
        reject(src, 'start-badheist')
        return
    end

    -- Starting a heist burns a cooldown and pings PD. Make sure the player is
    -- actually at the door before either of those happens.
    if not near(src, heist.startCoords) then
        reject(src, 'start-distance', 'You are not at the target.')
        return
    end

    if sessions[src] then
        exports['hc-core']:Notify(src, 'Finish your current hit first.', 'error')
        return
    end

    if Config.RequireCops and copsOnDuty() < heist.minCops then
        exports['hc-core']:Notify(src, 'Not enough police on duty.', 'error')
        return
    end

    local row = MySQL.single.await(
        'SELECT expires_at FROM hc_heist_cooldowns WHERE heist_key = ? AND citizenid = ? AND expires_at > NOW() ORDER BY id DESC LIMIT 1',
        { key, Player.PlayerData.citizenid }
    )
    if row then
        exports['hc-core']:Notify(src, 'Heist on cooldown for you.', 'error')
        return
    end

    MySQL.insert.await(
        'INSERT INTO hc_heist_cooldowns (heist_key, citizenid, expires_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))',
        { key, Player.PlayerData.citizenid, heist.cooldownMinutes }
    )

    sessions[src] = { key = key, startedAt = os.time(), loots = {}, paid = false }
    TriggerClientEvent('hc-heists:client:started', src, heist.key, heist.label)
    if Config.PdAlertOnStart then
        exports['hc-core']:AlertPolice(src, '10-90 Alarm: ' .. heist.label)
    end
end)

RegisterNetEvent('hc-heists:server:loot', function(key, index)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'heists:loot', 1500) then return end
    local session = sessions[src]
    if not session or session.key ~= key then return end
    local heist = getHeist(key)
    if not heist or type(index) ~= 'number' or not heist.loots[index] then return end
    if session.loots[index] then return end
    local ped = GetPlayerPed(src)
    if ped == 0 then return end
    if #(GetEntityCoords(ped) - heist.loots[index]) > 6.0 then return end
    session.loots[index] = true
end)

RegisterNetEvent('hc-heists:server:complete', function(key)
    local src = source
    if not exports['hc-core']:RateLimit(src, 'heists:complete', 2000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local heist = getHeist(key)
    if not heist then return end
    local session = sessions[src]
    if not session or session.key ~= key or session.paid then
        exports['hc-core']:Notify(src, 'No active heist.', 'error')
        return
    end

    local need = #heist.loots
    local got = 0
    for i = 1, need do
        if session.loots[i] then got = got + 1 end
    end
    if got < need then
        exports['hc-core']:Notify(src, 'You missed a case.', 'error')
        return
    end

    local minSeconds = math.max(12, need * (Config.MinSecondsPerLoot or 4))
    if (os.time() - session.startedAt) < minSeconds then
        exports['hc-core']:Notify(src, 'Too fast — finish the hit properly.', 'error')
        return
    end

    session.paid = true
    local pay = math.random(heist.payoutMin, heist.payoutMax)
    local ok, cfg = pcall(function()
        return exports['hc-core']:GetConfig()
    end)
    if ok and cfg and cfg.Economy then
        pay = math.floor(pay * (cfg.Economy.heistPayoutMultiplier or 1.0))
    end
    Player.Functions.AddMoney('cash', pay, 'hc-heist-' .. key)
    exports['hc-core']:LogMoney(src, 'hc-heist-' .. key, pay, heist.label)
    exports.ox_inventory:AddItem(src, 'hc_heist_bag', 1)
    exports['hc-core']:Notify(src, ('Heist payout $%s'):format(pay), 'success')
    sessions[src] = nil
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)
