CreateThread(function()
    exports.ox_target:addBoxZone({
        coords = Config.Shop.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_weapons_shop',
                icon = 'fa-solid fa-gun',
                label = Config.Shop.label,
                onSelect = function()
                    local options = {
                        { title = '— Realistic —', disabled = true },
                    }
                    for _, w in ipairs(Config.Realistic) do
                        options[#options + 1] = {
                            title = w.label,
                            description = ('$%s'):format(w.price),
                            onSelect = function()
                                TriggerServerEvent('hc-weapons:server:buy', w.item, false)
                            end,
                        }
                    end
                    options[#options + 1] = { title = '— Custom (paid) —', disabled = true }
                    for _, w in ipairs(Config.Custom) do
                        options[#options + 1] = {
                            title = w.label,
                            description = ('$%s — owner custom'):format(w.price),
                            onSelect = function()
                                TriggerServerEvent('hc-weapons:server:buy', w.item, true)
                            end,
                        }
                    end
                    lib.registerContext({ id = 'hc_weapons', title = Config.Shop.label, options = options })
                    lib.showContext('hc_weapons')
                end,
            },
        },
    })
end)
