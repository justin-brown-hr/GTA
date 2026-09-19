local function addDealerBlip(coords, sprite, colour, name)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, sprite)
    SetBlipScale(blip, 0.75)
    SetBlipColour(blip, colour)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(name)
    EndTextCommandSetBlipName(blip)
end

CreateThread(function()
    addDealerBlip(Config.PublicLot.coords, 326, 3, Config.PublicLot.label)
    addDealerBlip(Config.ExclusiveLot.coords, 326, 5, Config.ExclusiveLot.label)

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
                            icon = 'fa-solid fa-circle-info',
                        },
                    }
                    if Config.ExclusiveLot.storeUrl then
                        options[#options + 1] = {
                            title = 'Store link',
                            description = Config.ExclusiveLot.storeUrl,
                            icon = 'fa-solid fa-cart-shopping',
                        }
                    end
                    for _, v in ipairs(Config.ExclusiveLot.vehicles) do
                        options[#options + 1] = {
                            title = v.label,
                            description = v.priceUsd
                                and ('$%s USD — real money only'):format(v.priceUsd)
                                or 'Exclusive — real money only',
                            icon = 'fa-solid fa-gem',
                            onSelect = function()
                                lib.notify({
                                    title = v.label,
                                    description = ('Buy this on the Heartless store. It is delivered to your garage automatically — you do not need to be online.%s'):format(
                                        Config.ExclusiveLot.storeUrl and ('\n' .. Config.ExclusiveLot.storeUrl) or ''
                                    ),
                                    type = 'inform',
                                    duration = 12000,
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

RegisterNetEvent('hc-dealership:client:spawnPurchased', function(model, plate, exclusive)
    local spawn = exclusive and Config.ExclusiveSpawn or Config.PublicSpawn
    lib.requestModel(model)
    local veh = CreateVehicle(joaat(model), spawn.x, spawn.y, spawn.z, spawn.w, true, false)
    SetVehicleNumberPlateText(veh, plate)
    SetVehicleOnGroundProperly(veh)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(model)
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
end)
