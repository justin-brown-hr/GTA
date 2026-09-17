local QBCore = exports['qb-core']:GetCoreObject()

RegisterNetEvent('hc-zombie:server:enter', function()
    local src = source
    SetPlayerRoutingBucket(src, Config.Bucket)
    TriggerClientEvent('hc-zombie:client:entered', src)
    exports['hc-core']:Notify(src, 'Entered the Deadzone.', 'warning')
    -- TODO: spawn zombie peds / densify population in bucket only
end)

RegisterNetEvent('hc-zombie:server:exit', function()
    local src = source
    SetPlayerRoutingBucket(src, Config.ReturnBucket)
    exports['hc-core']:Notify(src, 'Extracted back to Heartless City.', 'success')
end)

AddEventHandler('playerDropped', function()
    local src = source
    SetPlayerRoutingBucket(src, Config.ReturnBucket)
end)
