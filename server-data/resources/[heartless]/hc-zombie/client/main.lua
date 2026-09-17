CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = Config.Entrance.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_zombie_enter',
                icon = 'fa-solid fa-biohazard',
                label = 'Enter Deadzone',
                onSelect = function()
                    TriggerServerEvent('hc-zombie:server:enter')
                end,
            },
        },
    })

    exports.ox_target:addBoxZone({
        coords = Config.Exit.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_zombie_exit',
                icon = 'fa-solid fa-door-open',
                label = Config.Exit.label,
                onSelect = function()
                    TriggerServerEvent('hc-zombie:server:exit')
                end,
            },
        },
    })
end)

RegisterNetEvent('hc-zombie:client:entered', function()
    lib.notify({
        title = 'Deadzone',
        description = Config.LootHint,
        type = 'warning',
        duration = 10000,
    })
end)
