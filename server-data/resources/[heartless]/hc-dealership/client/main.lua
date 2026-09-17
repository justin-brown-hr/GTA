CreateThread(function()
    -- Public lot
    exports.ox_target:addBoxZone({
        coords = Config.PublicLot.coords,
        size = vec3(2.5, 2.5, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_public_dealer',
                icon = 'fa-solid fa-car',
                label = Config.PublicLot.label,
                onSelect = function()
                    local options = {}
                    for _, v in ipairs(Config.PublicLot.vehicles) do
                        options[#options + 1] = {
                            title = v.label,
                            description = ('$%s'):format(v.price),
                            onSelect = function()
                                TriggerServerEvent('hc-dealership:server:buyPublic', v.model)
                            end,
                        }
                    end
                    lib.registerContext({ id = 'hc_public_dealer', title = Config.PublicLot.label, options = options })
                    lib.showContext('hc_public_dealer')
                end,
            },
        },
    })

    -- Exclusive lot (browse only — purchase via Tebex)
    exports.ox_target:addBoxZone({
        coords = Config.ExclusiveLot.coords,
        size = vec3(2.5, 2.5, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_exclusive_dealer',
                icon = 'fa-solid fa-gem',
                label = Config.ExclusiveLot.label,
                onSelect = function()
                    local options = {
                        {
                            title = 'How to buy',
                            description = Config.ExclusiveLot.buyHint,
                        },
                    }
                    for _, v in ipairs(Config.ExclusiveLot.vehicles) do
                        options[#options + 1] = {
                            title = v.label,
                            description = 'Exclusive — real money only',
                            onSelect = function()
                                lib.notify({
                                    title = 'Exclusive',
                                    description = 'Buy this package on Tebex. It will be granted automatically.',
                                    type = 'inform',
                                })
                            end,
                        }
                    end
                    lib.registerContext({ id = 'hc_exclusive_dealer', title = Config.ExclusiveLot.label, options = options })
                    lib.showContext('hc_exclusive_dealer')
                end,
            },
        },
    })
end)

RegisterNetEvent('hc-dealership:client:spawnPurchased', function(model, plate)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    lib.requestModel(model)
    local veh = CreateVehicle(joaat(model), coords.x + 3.0, coords.y, coords.z, GetEntityHeading(ped), true, false)
    SetVehicleNumberPlateText(veh, plate)
    TaskWarpPedIntoVehicle(ped, veh, -1)
    SetModelAsNoLongerNeeded(model)
end)
