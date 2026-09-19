CreateThread(function()
    for _, shop in ipairs(Config.Shops) do
        local blip = AddBlipForCoord(shop.coords.x, shop.coords.y, shop.coords.z)
        SetBlipSprite(blip, 73)
        SetBlipScale(blip, 0.7)
        SetBlipAsShortRange(blip, false)
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
                        if GetResourceState('illenium-appearance') == 'started' then
                            TriggerEvent(shop.appearanceEvent)
                        elseif GetResourceState('qb-clothing') == 'started' then
                            TriggerEvent(shop.qbEvent)
                        else
                            lib.notify({
                                title = shop.label,
                                description = 'Install illenium-appearance or qb-clothing.',
                                type = 'error',
                            })
                        end
                    end,
                },
            },
        })
    end
end)
