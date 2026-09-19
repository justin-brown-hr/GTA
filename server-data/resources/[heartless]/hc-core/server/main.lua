local QBCore = exports['qb-core']:GetCoreObject()

print(('^2[%s]^7 core loaded — Discord %s'):format(Config.ServerName, Config.DiscordInvite))

--- Server-side notify helper
---@param src number
---@param msg string
---@param nType? string
---@param duration? number
function HCNotify(src, msg, nType, duration)
    TriggerClientEvent('hc-core:client:notify', src, msg, nType, duration)
end

exports('Notify', HCNotify)
exports('GetConfig', function()
    return Config
end)

--- Ping on-duty police (used by drugs / scam / heists)
---@param src number
---@param message string
function HCAlertPolice(src, message)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
        local P = QBCore.Functions.GetPlayer(playerId)
        if P and P.PlayerData.job and P.PlayerData.job.name == 'police' and P.PlayerData.job.onduty then
            HCNotify(playerId, message, 'error', 9000)
            TriggerClientEvent('hc-core:client:policeBlip', playerId, coords, message)
        end
    end
    pcall(function()
        TriggerEvent('police:server:policeAlert', message)
    end)
end

exports('AlertPolice', HCAlertPolice)

QBCore.Commands.Add('hcinfo', 'Heartless City server info', {}, false, function(source)
    HCNotify(source, ('%s | Jobs, businesses, drugs, heists, shops, Deadzone'):format(Config.ServerName), 'primary', 7000)
end)

QBCore.Commands.Add('hcdiscord', 'Show Heartless City Discord invite', {}, false, function(source)
    HCNotify(source, Config.DiscordInvite, 'primary', 10000)
end)

-- Ensure business seed rows exist after DB is up
CreateThread(function()
    Wait(5000)
    local ok = pcall(function()
        MySQL.query.await([[
            INSERT INTO hc_businesses (business_key, label, price, balance)
            VALUES
              ('ls_customs', 'Heartless Customs', 250000, 0),
              ('vinewood_bar', 'Vinewood Pour House', 175000, 0),
              ('grove_247', 'Grove 24/7', 120000, 0),
              ('mirror_gunlease', 'Mirror Park Armory Lease', 300000, 0),
              ('limeys', 'Limeys Juice', 90000, 0),
              ('galaxy_club', 'Galaxy Club', 400000, 0)
            ON DUPLICATE KEY UPDATE label = VALUES(label)
        ]])
    end)
    if Config.Debug then
        print(ok and '[hc-core] Business seeds OK' or '[hc-core] Business seed skipped (table missing — import database/schema.sql)')
    end
end)
