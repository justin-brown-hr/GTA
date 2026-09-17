local QBCore = exports['qb-core']:GetCoreObject()

local function getHeist(key)
    for _, h in ipairs(Config.Heists) do
        if h.key == key then return h end
    end
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
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local heist = getHeist(key)
    if not heist then return end

    if copsOnDuty() < heist.minCops then
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

    TriggerClientEvent('hc-heists:client:started', src, heist.label)
    -- Scaffold: stages, loot props, finish event → payout
end)

RegisterNetEvent('hc-heists:server:complete', function(key)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local heist = getHeist(key)
    if not heist then return end

    local pay = math.random(heist.payoutMin, heist.payoutMax)
    Player.Functions.AddMoney('cash', pay, 'hc-heist-' .. key)
    exports['hc-core']:Notify(src, ('Heist payout $%s'):format(pay), 'success')
end)
