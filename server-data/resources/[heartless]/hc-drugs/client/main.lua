local function doProgress(label)
    return lib.progressCircle({
        duration = 6500,
        label = label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@world_human_gardener_plant@male@base', clip = 'base' },
    })
end

local function addZone(name, coords, label, event, drugId, progressLabel)
    exports.ox_target:addBoxZone({
        coords = coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = name,
                icon = 'fa-solid fa-flask',
                label = label,
                onSelect = function()
                    if doProgress(progressLabel) then
                        TriggerServerEvent(event, drugId)
                    end
                end,
            },
        },
    })
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 496)
    SetBlipScale(blip, 0.55)
    SetBlipColour(blip, 25)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(blip)
end

CreateThread(function()
    for _, drug in ipairs(Config.Drugs) do
        addZone('hc_gather_' .. drug.id, drug.gatherCoords, 'Gather ' .. drug.label, 'hc-drugs:server:gather', drug.id, 'Gathering...')
        addZone('hc_process_' .. drug.id, drug.processCoords, 'Process ' .. drug.label, 'hc-drugs:server:process', drug.id, 'Processing...')
    end

    local pedHash = Config.SellPed.model
    lib.requestModel(pedHash)
    local c = Config.SellPed.coords
    local ped = CreatePed(0, pedHash, c.x, c.y, c.z - 1.0, c.w, false, true)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports.ox_target:addLocalEntity(ped, {
        {
            name = 'hc_drug_sell',
            icon = 'fa-solid fa-dollar-sign',
            label = 'Sell product',
            onSelect = function()
                local options = {}
                for _, drug in ipairs(Config.Drugs) do
                    options[#options + 1] = {
                        title = drug.label,
                        description = ('Sell %s'):format(drug.productItem),
                        onSelect = function()
                            if lib.progressCircle({
                                duration = 4000,
                                label = 'Making a deal...',
                                position = 'bottom',
                                canCancel = true,
                                disable = { move = true, combat = true },
                            }) then
                                TriggerServerEvent('hc-drugs:server:sell', drug.id)
                            end
                        end,
                    }
                end
                lib.registerContext({ id = 'hc_drug_sell', title = 'Street Buyer', options = options })
                lib.showContext('hc_drug_sell')
            end,
        },
    })
end)
