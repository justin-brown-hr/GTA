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

QBCore.Commands.Add('hcinfo', 'Heartless City server info', {}, false, function(source)
    HCNotify(source, ('%s | Milestone 1: Jobs + Businesses'):format(Config.ServerName), 'primary', 7000)
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
              ('mirror_gunlease', 'Mirror Park Armory Lease', 300000, 0)
            ON DUPLICATE KEY UPDATE label = VALUES(label)
        ]])
    end)
    if Config.Debug then
        print(ok and '[hc-core] Business seeds OK' or '[hc-core] Business seed skipped (table missing — import database/schema.sql)')
    end
end)
