--[[
    Deadzone client.

    Never decides an outcome — the server owns spawns, kills, loot and payouts.
    This file does the things only the game client can:

    * resolve real ground height (and dodge water) for every point, because the
      config only knows x/y precisely;
    * drive the zombies this client has been handed network ownership of
      (OneSync gives each server-created ped to the nearest player);
    * draw crates, extract prompts and blips, and ask the server to act.
]]

local inZone = false
local wave = 1
local zombieGroup
local configured = {}   -- [ped] = true for zombies this client has set up
local crates = {}       -- [cacheIndex] = { obj = handle } once placed
local extracts = {}     -- [extractIndex] = vec3 once resolved
local zoneBlips = {}
local extracting = false
local promptShown = false

local function showPrompt(text)
    if not promptShown then lib.showTextUI(text); promptShown = true end
end

local function hidePrompt()
    if promptShown then lib.hideTextUI(); promptShown = false end
end

--[[ ---------------------------------------------------------------------
     Ground resolution
     ------------------------------------------------------------------ ]]

-- Probing downward returns the FIRST surface hit, so the start height matters:
-- from too high up it lands on roofs, containers and crane tops. Island points
-- only know x/y, so they start just above the island's tallest geometry (69m
-- per the map's own extents); points with a trusted height start just above it.
local ISLAND_PROBE_Z = 150.0

--- Ground height at x/y, or nil if collision there is not loaded yet.
local function groundAt(x, y, fromZ)
    fromZ = fromZ or ISLAND_PROBE_Z
    RequestCollisionAtCoord(x, y, fromZ)
    local found, z = GetGroundZFor_3dCoord(x, y, fromZ, false)
    if not found then return nil end
    -- Over water, "ground" is the seabed: treat as not usable.
    local water, wz = GetWaterHeightNoWaves(x, y, z + 50.0)
    if water and wz > z then return nil end
    return z
end

--- Nearest dry ground within `radius` of x/y, searching outward in rings.
local function dryGround(x, y, radius, fromZ)
    local z = groundAt(x, y, fromZ)
    if z then return vec3(x, y, z) end
    for r = 4.0, radius, 4.0 do
        for a = 0, 330, 30 do
            local px, py = x + r * math.cos(math.rad(a)), y + r * math.sin(math.rad(a))
            local pz = groundAt(px, py, fromZ)
            if pz then return vec3(px, py, pz) end
        end
    end
    return nil
end

--- Teleport onto real ground, waiting for collision to stream in first.
---@param trustZ boolean pos.z is accurate (city points) — probe just above it
local function safeTeleport(pos, heading, trustZ)
    local fromZ = trustZ and (pos.z + 3.0) or nil
    local ped = PlayerPedId()
    DoScreenFadeOut(400)
    while not IsScreenFadedOut() do Wait(10) end
    FreezeEntityPosition(ped, true)
    SetEntityCoords(ped, pos.x, pos.y, pos.z, false, false, false, false)

    local spot
    for _ = 1, 60 do -- up to ~6s for collision to load
        spot = dryGround(pos.x, pos.y, Config.SnapRadius, fromZ)
        if spot then break end
        Wait(100)
    end
    spot = spot or pos
    SetEntityCoords(ped, spot.x, spot.y, spot.z + 0.5, false, false, false, false)
    if heading then SetEntityHeading(ped, heading) end
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(600)
end

--[[ ---------------------------------------------------------------------
     City gate (always present)
     ------------------------------------------------------------------ ]]

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
                canInteract = function() return not inZone end,
                onSelect = function()
                    TriggerServerEvent('hc-zombie:server:enter')
                end,
            },
        },
    })
end)

--[[ ---------------------------------------------------------------------
     Zone setup / teardown
     ------------------------------------------------------------------ ]]

local function addZoneBlip(pos, sprite, colour, label)
    local b = AddBlipForCoord(pos.x, pos.y, pos.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, colour)
    SetBlipScale(b, 0.8)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    zoneBlips[#zoneBlips + 1] = b
end

local function removeCrate(i)
    local c = crates[i]
    if not c then return end
    if c.obj and DoesEntityExist(c.obj) then
        exports.ox_target:removeLocalEntity(c.obj)
        DeleteObject(c.obj)
    end
    crates[i] = nil
end

local function teardown()
    inZone = false
    extracting = false
    hidePrompt()
    for i in pairs(crates) do removeCrate(i) end
    crates, extracts, configured = {}, {}, {}
    for _, b in ipairs(zoneBlips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    zoneBlips = {}
end

--- Crate props are LOCAL (non-networked) objects: nobody else needs to see
--- this player's crates, and the instance forbids networked client entities.
local function placeCrate(i, spot)
    lib.requestModel(Config.CacheProp)
    local obj = CreateObject(Config.CacheProp, spot.x, spot.y, spot.z, false, false, false)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(Config.CacheProp)
    exports.ox_target:addLocalEntity(obj, {
        {
            name = 'hc_dz_cache_' .. i,
            icon = 'fa-solid fa-box-open',
            label = 'Search crate',
            distance = 2.5,
            onSelect = function()
                if lib.progressCircle({
                    duration = 5000,
                    label = 'Searching crate...',
                    position = 'bottom',
                    canCancel = true,
                    disable = { move = true, combat = true, car = true },
                    anim = { dict = 'mini@repair', clip = 'fixing_a_ped' },
                }) then
                    TriggerServerEvent('hc-zombie:server:loot', i)
                end
            end,
        },
    })
    crates[i] = { obj = obj }
end

RegisterNetEvent('hc-zombie:client:entered', function(serverWave)
    teardown()
    inZone = true
    wave = serverWave or 1

    local _, grp = AddRelationshipGroup('HC_ZOMBIE')
    zombieGroup = grp
    SetRelationshipBetweenGroups(5, zombieGroup, `PLAYER`)
    SetRelationshipBetweenGroups(5, `PLAYER`, zombieGroup)

    local a = Config.Arrival
    safeTeleport(vec3(a.x, a.y, a.z), a.w)

    for _, p in ipairs(Config.Extracts) do addZoneBlip(p, 358, 2, 'Deadzone extract') end
    for _, p in ipairs(Config.Caches) do addZoneBlip(p, 478, 5, 'Supply crate') end

    lib.notify({
        title = 'Deadzone',
        description = ('Wave %s. Search crates, kill infected, reach an extract alive. Die in here and you lose your salvage.'):format(wave),
        type = 'warning',
        duration = 10000,
    })
end)

RegisterNetEvent('hc-zombie:client:left', function(teleport)
    local wasIn = inZone
    teardown()
    if wasIn and teleport then
        local r = Config.CityReturn
        safeTeleport(vec3(r.x, r.y, r.z), r.w, true)
    end
end)

RegisterNetEvent('hc-zombie:client:pullBack', function()
    if not inZone then return end
    local a = Config.Arrival
    safeTeleport(vec3(a.x, a.y, a.z), a.w)
end)

RegisterNetEvent('hc-zombie:client:wave', function(w)
    wave = w
    if inZone then
        lib.notify({ title = 'Deadzone', description = ('Wave %s — they are getting stronger.'):format(w), type = 'error', duration = 7000 })
    end
end)

RegisterNetEvent('hc-zombie:client:dzpos', function(line)
    print('[Deadzone] ' .. line)
    lib.setClipboard(line)
    lib.notify({ title = '/dzpos', description = line .. ' (copied)', type = 'inform', duration = 10000 })
end)

--[[ ---------------------------------------------------------------------
     Zombies — only the ones this client owns
     ------------------------------------------------------------------ ]]

local WALK = 'move_m@drunk@verydrunk'

local function nearestPlayerPed(from)
    local best, bestD
    for _, pid in ipairs(GetActivePlayers()) do
        local p = GetPlayerPed(pid)
        if p ~= 0 and not IsEntityDead(p) then
            local d = #(GetEntityCoords(p) - from)
            if not bestD or d < bestD then best, bestD = p, d end
        end
    end
    return best
end

local function setupZombie(ped)
    local state = Entity(ped).state
    if not state.hcInit then
        -- First owner only: snap to ground and set health for its wave.
        local c = GetEntityCoords(ped)
        local g = groundAt(c.x, c.y)
        if g then SetEntityCoords(ped, c.x, c.y, g, false, false, false, false) end
        local hp = Config.ZombieHealth + Config.ZombieHealthPerWave * ((state.hcZombie or 1) - 1)
        SetPedMaxHealth(ped, hp)
        SetEntityHealth(ped, hp)
        state:set('hcInit', true, true)
    end
    -- Behaviour is local to the owning client, so every new owner re-applies it.
    SetPedRelationshipGroupHash(ped, zombieGroup)
    SetBlockingOfNonTemporaryEvents(ped, true)
    RemoveAllPedWeapons(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)   -- always fight
    SetPedCombatAttributes(ped, 5, true)    -- fight armed players while unarmed
    SetPedCombatMovement(ped, 3)            -- offensive
    SetPedCombatRange(ped, 0)
    SetPedSuffersCriticalHits(ped, true)    -- headshots still kill
    SetPedConfigFlag(ped, 281, true)        -- no writhe
    SetPedCanRagdollFromPlayerImpact(ped, false)
    StopPedSpeaking(ped, true)
    DisablePedPainAudio(ped, true)
    lib.requestAnimSet(WALK)
    SetPedMovementClipset(ped, WALK, 1.0)
    configured[ped] = true
end

CreateThread(function()
    while true do
        if not inZone then
            Wait(1000)
        else
            Wait(500)
            local me = PlayerId()
            for _, ped in ipairs(GetGamePool('CPed')) do
                if not IsPedAPlayer(ped) and not IsEntityDead(ped)
                    and NetworkGetEntityOwner(ped) == me and Entity(ped).state.hcZombie then
                    if not configured[ped] then setupZombie(ped) end
                    if not IsPedInCombat(ped, 0) then
                        local target = nearestPlayerPed(GetEntityCoords(ped))
                        if target then TaskCombatPed(ped, target, 0, 16) end
                    end
                end
            end
            for ped in pairs(configured) do
                if not DoesEntityExist(ped) then configured[ped] = nil end
            end
        end
    end
end)

--[[ ---------------------------------------------------------------------
     Crates + extracts — placed lazily as collision streams in around you
     ------------------------------------------------------------------ ]]

CreateThread(function()
    while true do
        if not inZone then
            Wait(1000)
        else
            Wait(750)
            local pos = GetEntityCoords(PlayerPedId())
            for i, p in ipairs(Config.Caches) do
                if not crates[i] and #(vec2(pos.x, pos.y) - vec2(p.x, p.y)) < 120.0 then
                    local spot = dryGround(p.x, p.y, Config.SnapRadius)
                    if spot then placeCrate(i, spot) end
                end
            end
            for i, p in ipairs(Config.Extracts) do
                if not extracts[i] and #(vec2(pos.x, pos.y) - vec2(p.x, p.y)) < 120.0 then
                    extracts[i] = dryGround(p.x, p.y, Config.SnapRadius)
                end
            end
        end
    end
end)

-- Extract prompt + marker
CreateThread(function()
    while true do
        local sleep = 1000
        if inZone and not extracting then
            local pos = GetEntityCoords(PlayerPedId())
            local here
            for i, spot in pairs(extracts) do
                local d = #(pos - spot)
                if d < 30.0 then
                    sleep = 0
                    DrawMarker(1, spot.x, spot.y, spot.z - 1.0, 0, 0, 0, 0, 0, 0, 4.0, 4.0, 1.5, 60, 200, 90, 120, false, false, 2, false, nil, nil, false)
                    if d < 3.0 then here = i end
                end
            end
            if here then
                showPrompt('[E] Extract with your salvage')
                if IsControlJustReleased(0, 38) then
                    hidePrompt()
                    extracting = true
                    TriggerServerEvent('hc-zombie:server:extractStart', here)
                    if lib.progressCircle({
                        duration = Config.ExtractSeconds * 1000,
                        label = 'Signalling extraction...',
                        position = 'bottom',
                        canCancel = true,
                        disable = { move = true, car = true },
                    }) then
                        TriggerServerEvent('hc-zombie:server:exit', here)
                    end
                    extracting = false
                end
            else
                hidePrompt()
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then teardown() end
end)
