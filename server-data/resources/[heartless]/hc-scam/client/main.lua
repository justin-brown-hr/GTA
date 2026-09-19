CreateThread(function()
    local blip = AddBlipForCoord(Config.Shop.coords.x, Config.Shop.coords.y, Config.Shop.coords.z)
    SetBlipSprite(blip, 496)
    SetBlipScale(blip, 0.65)
    SetBlipColour(blip, 40)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Shop.label)
    EndTextCommandSetBlipName(blip)

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

RegisterNetEvent('hc-scam:client:runUse', function(item, label)
    local ok = lib.progressCircle({
        duration = 8000,
        label = ('Using %s...'):format(label),
        position = 'bottom',
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@code_human_in_bus_passenger_idles@female@tablet@idle_a', clip = 'idle_a' },
    })
    TriggerServerEvent('hc-scam:server:finishUse', item, ok == true)
end)

RegisterNetEvent('hc-scam:client:used', function(item)
    lib.notify({ title = 'Scam Gear', description = ('Using %s — stay off the radar.'):format(item), type = 'inform' })
end)
