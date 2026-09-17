CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 73)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(shop.label)
        EndTextCommandSetBlipName(blip)

        exports.ox_target:addBoxZone({
            coords = shop.coords,
            size = vec3(2.0, 2.0, 2.5),
            rotation = 0,
            options = {
                {
                    name = shop.id,
                    icon = 'fa-solid fa-shirt',
                    label = 'Browse fashion',
                    onSelect = function()
                        -- Falls back to notify if appearance resource missing
                        local ok = pcall(function()
                            TriggerEvent(shop.appearanceEvent)
                        end)
                        if not ok then
                            lib.notify({
                                title = shop.label,
                                description = 'Install illenium-appearance (or change appearanceEvent in config).',
                                type = 'error',
                            })
                        end
                    end,
                },
            },
        })
    end
end)
