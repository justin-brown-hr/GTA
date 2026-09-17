local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(2500)
    TriggerEvent('QBCore:Notify', Locale.welcome:format(Config.DiscordInvite), 'primary', 8000)
end)

exports('GetConfig', function()
    return Config
end)

RegisterNetEvent('hc-core:client:notify', function(msg, nType, duration)
    TriggerEvent('QBCore:Notify', msg, nType or 'primary', duration or 5000)
end)
