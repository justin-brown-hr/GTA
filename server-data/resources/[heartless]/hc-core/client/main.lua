local QBCore = exports['qb-core']:GetCoreObject()

CreateThread(function()
    Wait(2500)
    TriggerEvent('QBCore:Notify', Locale.welcome:format(Config.DiscordInvite), 'primary', 8000)
    Wait(4000)
    TriggerEvent('QBCore:Notify', 'Open inventory with F2 (or /inv). City blips are on your pause map.', 'primary', 9000)
end)

exports('GetConfig', function()
    return Config
end)

RegisterNetEvent('hc-core:client:notify', function(msg, nType, duration)
    TriggerEvent('QBCore:Notify', msg, nType or 'primary', duration or 5000)
end)

RegisterNetEvent('hc-core:client:policeBlip', function(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 161)
    SetBlipScale(blip, 1.1)
    SetBlipColour(blip, 1)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Police alert')
    EndTextCommandSetBlipName(blip)
    SetTimeout(45000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)
