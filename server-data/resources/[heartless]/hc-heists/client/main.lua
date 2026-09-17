CreateThread(function()
    for _, heist in ipairs(Config.Heists) do
        exports.ox_target:addBoxZone({
            coords = heist.startCoords,
            size = vec3(1.5, 1.5, 2.0),
            rotation = 0,
            options = {
                {
                    name = 'hc_heist_' .. heist.key,
                    icon = 'fa-solid fa-mask',
                    label = 'Start ' .. heist.label,
                    onSelect = function()
                        local confirm = lib.alertDialog({
                            header = heist.label,
                            content = 'Start this heist? Police may be alerted.',
                            centered = true,
                            cancel = true,
                        })
                        if confirm == 'confirm' then
                            TriggerServerEvent('hc-heists:server:start', heist.key)
                        end
                    end,
                },
            },
        })
    end
end)

RegisterNetEvent('hc-heists:client:started', function(label)
    lib.notify({ title = 'Heist', description = label .. ' is live — complete objectives (scaffold).', type = 'warning' })
end)
