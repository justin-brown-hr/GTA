local active = {
    key = nil,
    loots = {},
    done = {},
    blips = {},
}

local function clearBlips()
    for _, b in ipairs(active.blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    active.blips = {}
end

local function getHeist(key)
    for _, h in ipairs(Config.Heists) do
        if h.key == key then return h end
    end
end

CreateThread(function()
    for _, heist in ipairs(Config.Heists) do
        local blip = AddBlipForCoord(heist.startCoords.x, heist.startCoords.y, heist.startCoords.z)
        SetBlipSprite(blip, 156)
        SetBlipScale(blip, 0.6)
        SetBlipColour(blip, 1)
        SetBlipAsShortRange(blip, false)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(heist.label)
        EndTextCommandSetBlipName(blip)

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
                            content = 'Hit this spot? Grab each marked case, then you get paid. Police may be pinged.',
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

RegisterNetEvent('hc-heists:client:started', function(key, label)
    local heist = getHeist(key)
    if not heist then return end
    clearBlips()
    active.key = key
    active.loots = heist.loots
    active.done = {}
    for i, coords in ipairs(heist.loots) do
        local b = AddBlipForCoord(coords.x, coords.y, coords.z)
        SetBlipSprite(b, 1)
        SetBlipColour(b, 1)
        SetBlipRoute(b, i == 1)
        active.blips[i] = b
    end
    lib.notify({
        title = 'Heist',
        description = label .. ' is live — loot every marked case ([E]).',
        type = 'warning',
        duration = 9000,
    })
end)

RegisterNetEvent('hc-heists:client:forceStop', function()
    clearBlips()
    active.key = nil
    active.loots = {}
    active.done = {}
end)

CreateThread(function()
    while true do
        local sleep = 1000
        if active.key then
            sleep = 0
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local shown = false
            for i, target in ipairs(active.loots) do
                if not active.done[i] and #(coords - target) < 12.0 then
                    shown = true
                    lib.showTextUI('[E] Crack case')
                    if IsControlJustReleased(0, 38) and #(coords - target) < 2.5 then
                        lib.hideTextUI()
                        if lib.progressCircle({
                            duration = Config.LootTimeMs or 7000,
                            label = 'Cracking the case...',
                            position = 'bottom',
                            canCancel = true,
                            disable = { move = true, combat = true },
                            anim = { dict = 'mini@repair', clip = 'fixing_a_player' },
                        }) then
                            active.done[i] = true
                            if active.blips[i] and DoesBlipExist(active.blips[i]) then
                                RemoveBlip(active.blips[i])
                            end
                            TriggerServerEvent('hc-heists:server:loot', active.key, i)
                            local remaining = 0
                            for n = 1, #active.loots do
                                if not active.done[n] then remaining = remaining + 1 end
                            end
                            if remaining == 0 then
                                TriggerServerEvent('hc-heists:server:complete', active.key)
                                clearBlips()
                                active.key = nil
                            else
                                lib.notify({ title = 'Heist', description = remaining .. ' cases left', type = 'inform' })
                            end
                        end
                    end
                    break
                end
            end
            if not shown then lib.hideTextUI() end
        else
            lib.hideTextUI()
        end
        Wait(sleep)
    end
end)
