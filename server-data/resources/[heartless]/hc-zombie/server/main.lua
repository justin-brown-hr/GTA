local QBCore = exports['qb-core']:GetCoreObject()

--[[
    Deadzone server — the authority for everything that has an outcome.

    * Players are moved into their own routing bucket, where ambient traffic is
      off and clients may not create networked entities at all ('strict'). The
      only things alive in there are players and the zombies this file creates.
    * A director spawns and culls zombies around whoever is inside, and raises
      the wave the longer the zone stays occupied.
    * Kills are read from the game's own death record (GetPedSourceOfDeath),
      never reported by a client. Loot, extraction and payouts are validated
      here; the client only asks.
]]

--- [src] = { enteredAt, kills, extract = { index, at } | nil, warnedAt }
local inside = {}
--- [entity] = { diedAt = os.time() | nil }
local zombies = {}
local lootCd = {}
local wave, occupiedSince = 1, nil

local function notify(src, msg, kind, ms)
    exports['hc-core']:Notify(src, msg, kind, ms)
end

local function rateLimit(src, key, ms)
    return exports['hc-core']:RateLimit(src, key, ms)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'zombie:' .. reason)
    if msg then notify(src, msg, 'error') end
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

--- Distance on the ground plane. Island points store x/y precisely but only a
--- z *hint* (real ground height is resolved in game), so height is ignored.
local function dist2d(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function near2d(src, point, radius)
    local c = pedCoords(src)
    return c ~= nil and dist2d(c, point) <= radius
end

local function countInside()
    local n = 0
    for _ in pairs(inside) do n = n + 1 end
    return n
end

--[[ ---------------------------------------------------------------------
     Zone membership
     ------------------------------------------------------------------ ]]

--- Take a player out of the Deadzone. Always safe to call.
---@param teleport boolean move them back to the city gate (false when dead —
---                       the normal death/respawn flow takes over from there)
local function leaveZone(src, teleport)
    inside[src] = nil
    SetPlayerRoutingBucket(src, Config.ReturnBucket)
    TriggerClientEvent('hc-zombie:client:left', src, teleport)
end

--- The only thing a player can lose in here is what they were carrying out.
local function forfeitSalvage(src)
    local n = exports.ox_inventory:GetItemCount(src, 'hc_dz_loot') or 0
    if n > 0 then
        exports.ox_inventory:RemoveItem(src, 'hc_dz_loot', n)
    end
    return n
end

RegisterNetEvent('hc-zombie:server:enter', function()
    local src = source
    if not rateLimit(src, 'zombie:enter', 3000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    if inside[src] then
        notify(src, 'You are already in the Deadzone.', 'error')
        return
    end
    if not near2d(src, Config.Entrance.coords, Config.GateDistance) then
        reject(src, 'enter-distance', 'You are not at the Deadzone gate.')
        return
    end
    local md = Player.PlayerData.metadata or {}
    if md.isdead or md.inlaststand then
        notify(src, 'You are in no state to go in there.', 'error')
        return
    end

    inside[src] = { enteredAt = os.time(), kills = 0 }
    occupiedSince = occupiedSince or os.time()
    SetPlayerRoutingBucket(src, Config.Bucket)
    TriggerClientEvent('hc-zombie:client:entered', src, wave)
    notify(src, ('Entered the Deadzone — wave %s.'):format(wave), 'warning')
end)

--[[ ---------------------------------------------------------------------
     Loot
     ------------------------------------------------------------------ ]]

local function rollLoot()
    local total = 0
    for _, e in ipairs(Config.LootTable) do total = total + e.weight end
    local pick = math.random() * total
    for _, e in ipairs(Config.LootTable) do
        pick = pick - e.weight
        if pick <= 0 then return e.item, math.random(e.min, e.max) end
    end
    local last = Config.LootTable[#Config.LootTable]
    return last.item, last.min
end

RegisterNetEvent('hc-zombie:server:loot', function(index)
    local src = source
    if not rateLimit(src, 'zombie:loot', 2000) then return end
    if not inside[src] then
        reject(src, 'loot-outside')
        return
    end
    index = tonumber(index)
    local point = index and Config.Caches[index]
    if not point then
        reject(src, 'loot-badindex')
        return
    end
    -- The client places the crate on resolved ground, which can be up to
    -- SnapRadius from the configured x/y when the exact spot was water.
    if not near2d(src, point, Config.PointTolerance) then
        reject(src, 'loot-distance', 'You are not at that cache.')
        return
    end

    local key = src .. ':' .. index
    local now = os.time()
    if lootCd[key] and (now - lootCd[key]) < Config.CacheCooldownSeconds then
        notify(src, 'Already picked this cache clean.', 'error')
        return
    end
    lootCd[key] = now

    local item, count = rollLoot()
    if exports.ox_inventory:AddItem(src, item, count) then
        local def = exports.ox_inventory:Items(item)
        notify(src, ('Found %sx %s.'):format(count, def and def.label or item), 'success')
    else
        lootCd[key] = nil
        notify(src, 'Your bag is full.', 'error')
    end
end)

--[[ ---------------------------------------------------------------------
     Extraction — two steps so it cannot be done instantly:
       extractStart: player is at a point → the clock starts
       exit:         same point, still there, clock has run → paid out
     ------------------------------------------------------------------ ]]

RegisterNetEvent('hc-zombie:server:extractStart', function(index)
    local src = source
    if not rateLimit(src, 'zombie:extractStart', 1500) then return end
    local session = inside[src]
    index = tonumber(index)
    local point = index and Config.Extracts[index]
    if not session or not point then
        reject(src, 'extract-invalid')
        return
    end
    if not near2d(src, point, Config.PointTolerance) then
        reject(src, 'extract-distance', 'Get to the extraction point first.')
        return
    end
    session.extract = { index = index, at = os.time() }
end)

RegisterNetEvent('hc-zombie:server:exit', function(index)
    local src = source
    if not rateLimit(src, 'zombie:exit', 3000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local session = inside[src]
    if not session then
        -- This event once paid out unconditionally. Anyone reaching this
        -- branch is desynced or fishing for free cash.
        reject(src, 'exit-not-inside', 'You are not in the Deadzone.')
        SetPlayerRoutingBucket(src, Config.ReturnBucket)
        return
    end

    index = tonumber(index)
    local point = index and Config.Extracts[index]
    local ex = session.extract
    if not point or not ex or ex.index ~= index then
        reject(src, 'exit-nostart', 'Hold the extraction point first.')
        return
    end
    if (os.time() - ex.at) < (Config.ExtractSeconds - 1) then
        reject(src, 'exit-toofast', 'Extraction was interrupted.')
        return
    end
    if not near2d(src, point, Config.PointTolerance) then
        session.extract = nil
        reject(src, 'exit-distance', 'You left the extraction point.')
        return
    end

    -- Payout is tied to salvage carried out plus kills the server saw — never
    -- to the act of leaving.
    local carried = exports.ox_inventory:GetItemCount(src, 'hc_dz_loot') or 0
    local kills = session.kills
    leaveZone(src, true)

    local pay = 0
    if carried > 0 then
        if not exports.ox_inventory:RemoveItem(src, 'hc_dz_loot', carried) then
            notify(src, 'Could not hand in your salvage — keep it and try again.', 'error')
            return
        end
        for _ = 1, carried do
            pay = pay + math.random(Config.SalvagePerLootMin, Config.SalvagePerLootMax)
        end
    end
    pay = math.min(pay + kills * Config.KillBonus, Config.ExtractCashMax)

    if pay <= 0 then
        notify(src, 'Extracted empty-handed — no salvage, no kills, no payout.', 'inform')
        return
    end
    Player.Functions.AddMoney('cash', pay, 'hc-deadzone-extract')
    exports['hc-core']:LogMoney(src, 'hc-deadzone-extract', pay, ('%s salvage, %s kills'):format(carried, kills))
    notify(src, ('Extracted: %s salvage, %s kills. Paid $%s'):format(carried, kills, pay), 'success', 9000)
end)

--[[ ---------------------------------------------------------------------
     The director
     ------------------------------------------------------------------ ]]

local function despawnAll()
    for ent in pairs(zombies) do
        if DoesEntityExist(ent) then DeleteEntity(ent) end
    end
    zombies = {}
end

--- Which player (server id) a killer entity belongs to, if any.
local function killerSource(killer)
    if not killer or killer == 0 or not DoesEntityExist(killer) then return nil end
    if GetEntityType(killer) == 2 then -- vehicle: credit the driver
        killer = GetPedInVehicleSeat(killer, -1)
        if not killer or killer == 0 then return nil end
    end
    if not IsPedAPlayer(killer) then return nil end
    for src in pairs(inside) do
        if GetPlayerPed(src) == killer then return src end
    end
    return nil
end

local function spawnZombieNear(src)
    local c = pedCoords(src)
    if not c then return end
    local d = Config.Director
    local angle = math.random() * math.pi * 2
    local r = d.spawnMinDistance + math.random() * (d.spawnMaxDistance - d.spawnMinDistance)
    local x, y = c.x + math.cos(angle) * r, c.y + math.sin(angle) * r

    -- Keep spawns inside the zone: pull the point toward the centre if needed.
    local ctr = Config.Zone.center
    local fromCtr = math.sqrt((x - ctr.x) ^ 2 + (y - ctr.y) ^ 2)
    if fromCtr > Config.Zone.radius then
        local k = (Config.Zone.radius - 10.0) / fromCtr
        x, y = ctr.x + (x - ctr.x) * k, ctr.y + (y - ctr.y) * k
    end

    local model = Config.ZombieModels[math.random(#Config.ZombieModels)]
    -- Spawned at the player's height; the owning client snaps it to the ground.
    local ped = CreatePed(4, model, x, y, c.z + 1.0, math.random() * 360.0, true, true)
    if not ped or ped == 0 then return end
    SetEntityRoutingBucket(ped, Config.Bucket)
    Entity(ped).state:set('hcZombie', wave, true)
    zombies[ped] = {}
end

local function tick()
    local now = os.time()
    local d = Config.Director

    -- 1. Players: deaths, strays, disconnect leftovers.
    local positions = {}
    for src, session in pairs(inside) do
        local Player = QBCore.Functions.GetPlayer(src)
        local ped = GetPlayerPed(src)
        if not Player or not ped or ped == 0 then
            inside[src] = nil
        else
            local md = Player.PlayerData.metadata or {}
            if GetEntityHealth(ped) <= 0 or md.isdead or md.inlaststand then
                local lost = forfeitSalvage(src)
                leaveZone(src, false)
                notify(src, lost > 0 and ('You went down in the Deadzone and lost %s salvage.'):format(lost)
                    or 'You went down in the Deadzone.', 'error', 9000)
            else
                local c = GetEntityCoords(ped)
                local out = dist2d(c, Config.Zone.center) - Config.Zone.radius
                if out > 60.0 then
                    TriggerClientEvent('hc-zombie:client:pullBack', src)
                    notify(src, 'The fog closes in — you are dragged back.', 'error')
                elseif out > 20.0 and (not session.warnedAt or now - session.warnedAt > 10) then
                    session.warnedAt = now
                    notify(src, 'Turn back — you are leaving the Deadzone.', 'warning')
                end
                positions[#positions + 1] = c
            end
        end
    end

    local players = #positions
    if players == 0 then
        if next(zombies) then despawnAll() end
        wave, occupiedSince = 1, nil
        return
    end

    -- 2. Wave.
    occupiedSince = occupiedSince or now
    local newWave = math.min(d.maxWave, 1 + math.floor((now - occupiedSince) / (d.waveMinutes * 60)))
    if newWave ~= wave then
        wave = newWave
        for src in pairs(inside) do
            TriggerClientEvent('hc-zombie:client:wave', src, wave)
        end
    end

    -- 3. Zombies: deaths (credit the killer), corpses, stragglers.
    local alive = 0
    for ent, z in pairs(zombies) do
        if not DoesEntityExist(ent) then
            zombies[ent] = nil
        elseif GetEntityHealth(ent) <= 0 then
            if not z.diedAt then
                z.diedAt = now
                local killer = killerSource(GetPedSourceOfDeath(ent))
                if killer and inside[killer] then
                    inside[killer].kills = inside[killer].kills + 1
                end
            elseif now - z.diedAt > d.corpseSeconds then
                DeleteEntity(ent)
                zombies[ent] = nil
            end
        else
            local zc = GetEntityCoords(ent)
            local closest = math.huge
            for _, pc in ipairs(positions) do
                closest = math.min(closest, dist2d(zc, pc))
            end
            if closest > d.despawnDistance then
                DeleteEntity(ent)
                zombies[ent] = nil
            else
                alive = alive + 1
            end
        end
    end

    -- 4. Top up toward the target, a few per tick so it builds, not pops.
    local target = math.min(d.maxAlive, d.basePerPlayer * players + d.waveBonus * (wave - 1))
    local srcs = {}
    for src in pairs(inside) do srcs[#srcs + 1] = src end
    for _ = 1, math.min(3, target - alive) do
        spawnZombieNear(srcs[math.random(#srcs)])
    end
end

CreateThread(function()
    -- The instance: no ambient peds/traffic, and clients may not create
    -- networked entities in it — the only NPCs are the ones spawned here.
    SetRoutingBucketPopulationEnabled(Config.Bucket, false)
    SetRoutingBucketEntityLockdownMode(Config.Bucket, 'strict')

    -- Anyone left inside the instance by a restart gets brought home.
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if GetPlayerRoutingBucket(src) == Config.Bucket then
            leaveZone(src, true)
        end
    end

    while true do
        Wait(Config.Director.tickSeconds * 1000)
        local ok, err = pcall(tick)
        if not ok then print(('^1[hc-zombie]^7 director error: %s'):format(err)) end
    end
end)

--[[ ---------------------------------------------------------------------
     Cleanup + staff tools
     ------------------------------------------------------------------ ]]

local function forget(src)
    inside[src] = nil
    local prefix = src .. ':'
    for key in pairs(lootCd) do
        if key:sub(1, #prefix) == prefix then lootCd[key] = nil end
    end
end

AddEventHandler('playerDropped', function()
    local src = source
    forget(src)
    SetPlayerRoutingBucket(src, Config.ReturnBucket)
end)

-- Switching character mid-zone must not leave anyone in the instance.
AddEventHandler('QBCore:Server:OnPlayerUnload', function(src)
    if inside[src] then
        forget(src)
        SetPlayerRoutingBucket(src, Config.ReturnBucket)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    despawnAll()
    for src in pairs(inside) do
        SetPlayerRoutingBucket(src, Config.ReturnBucket)
    end
end)

RegisterCommand('hc_dz_status', function(source)
    if source ~= 0 then return end
    local alive, dead = 0, 0
    for ent, z in pairs(zombies) do
        if DoesEntityExist(ent) and not z.diedAt then alive = alive + 1 else dead = dead + 1 end
    end
    print(('[hc-zombie] players inside: %s  wave: %s  zombies alive: %s  corpses: %s'):format(
        countInside(), wave, alive, dead))
    for src, s in pairs(inside) do
        print(('  %s (%s)  in for %ss  kills %s'):format(GetPlayerName(src), src, os.time() - s.enteredAt, s.kills))
    end
end, true)

-- Staff: print your exact position, for tuning cache/extract points in config.
QBCore.Commands.Add('dzpos', 'Print your coords for Deadzone config (staff)', {}, false, function(source)
    local c = pedCoords(source)
    if not c then return end
    local line = ('vec3(%.1f, %.1f, %.1f)'):format(c.x, c.y, c.z)
    print(('[hc-zombie] /dzpos %s: %s'):format(GetPlayerName(source), line))
    TriggerClientEvent('hc-zombie:client:dzpos', source, line)
end, 'admin')
