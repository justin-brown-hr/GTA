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

--- Server-set plates are applied by whichever client owns the vehicle, so make
--- sure it stuck once we are driving it — keys are matched by plate.
local function ensurePlate(veh, plate)
    if not plate then return end
    for _ = 1, 40 do -- up to ~2s for ownership to pass to us after the warp
        if NetworkGetEntityOwner(veh) == PlayerId() then break end
        Wait(50)
    end
    local current = (GetVehicleNumberPlateText(veh) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if current ~= plate and NetworkGetEntityOwner(veh) == PlayerId() then
        SetVehicleNumberPlateText(veh, plate)
    end
end

--- The server created the car (and gave the keys); get the buyer into it once
--- it has streamed in on this client.
RegisterNetEvent('hc-dealership:client:vehicleReady', function(netId, plate)
    for _ = 1, 100 do -- up to ~5s
        if NetworkDoesNetworkIdExist(netId) then
            local veh = NetToVeh(netId)
            if veh ~= 0 and DoesEntityExist(veh) then
                TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
                ensurePlate(veh, plate)
                return
            end
        end
        Wait(50)
    end
    lib.notify({ title = 'Dealership', description = 'Your new car is on the lot.', type = 'inform' })
end)
