local inZone = false
local zombies = {}

local function wipeZombies()
    for _, ped in ipairs(zombies) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    zombies = {}
end

CreateThread(function()
    local e = Config.Entrance.coords
    local blip = AddBlipForCoord(e.x, e.y, e.z)
    SetBlipSprite(blip, 310)
    SetBlipScale(blip, 0.8)
    SetBlipColour(blip, 1)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Entrance.label)
    EndTextCommandSetBlipName(blip)

    exports.ox_target:addBoxZone({
        coords = Config.Entrance.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_zombie_enter',
                icon = 'fa-solid fa-biohazard',
                label = 'Enter Deadzone',
                onSelect = function()
                    TriggerServerEvent('hc-zombie:server:enter')
                end,
            },
        },
    })

    exports.ox_target:addBoxZone({
        coords = Config.Exit.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        options = {
            {
                name = 'hc_zombie_exit',
                icon = 'fa-solid fa-door-open',
                label = Config.Exit.label,
                onSelect = function()
                    TriggerServerEvent('hc-zombie:server:exit')
                end,
            },
        },
    })

    for i, coords in ipairs(Config.Caches) do
        exports.ox_target:addBoxZone({
            coords = coords,
            size = vec3(1.4, 1.4, 1.8),
            rotation = 0,
            options = {
                {
                    name = 'hc_dz_cache_' .. i,
                    icon = 'fa-solid fa-box',
                    label = 'Search cache',
                    canInteract = function()
                        return inZone
                    end,
                    onSelect = function()
                        if lib.progressCircle({
                            duration = 5000,
                            label = 'Searching cache...',
                            position = 'bottom',
                            canCancel = true,
                            disable = { move = true, combat = true },
                        }) then
                            TriggerServerEvent('hc-zombie:server:loot', i)
                        end
                    end,
                },
            },
        })
    end
end)

RegisterNetEvent('hc-zombie:client:entered', function()
    inZone = true
    local s = Config.DeadzoneSpawn
    SetEntityCoords(PlayerPedId(), s.x, s.y, s.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), s.w)
    lib.notify({
        title = 'Deadzone',
        description = Config.LootHint,
        type = 'warning',
        duration = 10000,
    })

    wipeZombies()
    lib.requestModel(Config.ZombieModel)
    for _, z in ipairs(Config.ZombieSpawns) do
        local ped = CreatePed(4, Config.ZombieModel, z.x, z.y, z.z, z.w, true, true)
        SetPedCombatAttributes(ped, 46, true)
        SetPedFleeAttributes(ped, 0, false)
        TaskCombatPed(ped, PlayerPedId(), 0, 16)
        zombies[#zombies + 1] = ped
    end
    SetModelAsNoLongerNeeded(Config.ZombieModel)
end)

RegisterNetEvent('hc-zombie:client:extracted', function()
    inZone = false
    wipeZombies()
    local r = Config.CityReturn
    SetEntityCoords(PlayerPedId(), r.x, r.y, r.z, false, false, false, false)
    SetEntityHeading(PlayerPedId(), r.w)
end)
