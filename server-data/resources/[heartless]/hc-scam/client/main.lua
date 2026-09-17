CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = Config.Shop.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_scam_shop',
                icon = 'fa-solid fa-user-secret',
                label = Config.Shop.label,
                onSelect = function()
                    local options = {}
                    for _, eq in ipairs(Config.Equipment) do
                        options[#options + 1] = {
                            title = eq.label,
                            description = ('$%s | cooldown %sm'):format(eq.price, eq.cooldownMinutes),
                            onSelect = function()
                                TriggerServerEvent('hc-scam:server:buy', eq.item)
                            end,
                        }
                    end
                    lib.registerContext({ id = 'hc_scam_shop', title = Config.Shop.label, options = options })
                    lib.showContext('hc_scam_shop')
                end,
            },
        },
    })
end)

-- Useable hooks will call server with risk checks when items are registered
RegisterNetEvent('hc-scam:client:used', function(item)
    lib.notify({ title = 'Scam Gear', description = ('Using %s — stay off the radar.'):format(item), type = 'inform' })
end)
