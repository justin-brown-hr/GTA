local QBCore = exports['qb-core']:GetCoreObject()

--[[
    The server owns the route: it hands us `stopIndices` (indices into
    Config.Jobs[].stops) and confirms each stop before we move on. Nothing here
    decides that a stop or a run is finished — it only asks.
]]
local active = {
    jobId = nil,
    label = nil,
    vehicle = nil,
    blip = nil,
    stopIndex = 0,      -- position in active.stopIndices (1-based)
    stopIndices = {},   -- server-issued indices into job.stops
    awaiting = false,   -- waiting on the server to confirm the current stop
    phase = 'idle',     -- idle | stops | sell | return
}

local function clearBlip()
    if active.blip and DoesBlipExist(active.blip) then
        RemoveBlip(active.blip)
    end
    active.blip = nil
end

local function setWaypoint(coords, text)
    clearBlip()
    active.blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(active.blip, 1)
    SetBlipColour(active.blip, 5)
    SetBlipRoute(active.blip, true)
    SetBlipScale(active.blip, 0.85)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(text or 'Job stop')
    EndTextCommandSetBlipName(active.blip)
    SetNewWaypoint(coords.x, coords.y)
end

-- The work vehicle belongs to the server: it spawns it, checks it is back at
-- the depot, and deletes it. The client only keeps a handle to it.
local function forgetJobVehicle()
    active.vehicle = nil
end

local function resetActive()
    clearBlip()
    forgetJobVehicle()
    active.jobId = nil
    active.label = nil
    active.stopIndex = 0
    active.stopIndices = {}
    active.awaiting = false
    active.phase = 'idle'
end

--- Resolve the current server-issued stop to world coords.
local function currentStopCoords(job)
    local index = active.stopIndices[active.stopIndex]
    return index and job.stops[index] or nil
end

local function getJobDef(id)
    for _, j in ipairs(Config.Jobs) do
        if j.id == id then return j end
    end
end

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

--- Get into the vehicle the server created at the depot. A networked entity
--- only exists on clients within range of it, so go there first.
local function enterWorkVehicle(job, netId, plate)
    if not netId then return end
    local d = job.depot
    local ped = PlayerPedId()
    if #(GetEntityCoords(ped) - vec3(d.x, d.y, d.z)) > 150.0 then
        DoScreenFadeOut(300)
        while not IsScreenFadedOut() do Wait(10) end
        SetEntityCoords(ped, d.x + 3.0, d.y, d.z, false, false, false, false)
    end
    local veh
    for _ = 1, 100 do -- up to ~5s to stream in
        if NetworkDoesNetworkIdExist(netId) then
            veh = NetToVeh(netId)
            if veh ~= 0 and DoesEntityExist(veh) then break end
        end
        Wait(50)
    end
    if veh and veh ~= 0 then
        TaskWarpPedIntoVehicle(ped, veh, -1)
        active.vehicle = veh
        ensurePlate(veh, plate)
    else
        lib.notify({ title = 'Jobs', description = 'Your work vehicle is at the depot.', type = 'inform' })
    end
    if IsScreenFadedOut() then DoScreenFadeIn(500) end
end

local function doProgress(label)
    return lib.progressCircle({
        duration = Config.ProgressMs,
        label = label,
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = {
            dict = 'anim@gangops@facility@servers@bodysearch@',
            clip = 'player_search',
        },
    })
end

--- Called only from hc-jobs:client:stopConfirmed — the server has accepted the
--- stop we just worked and told us how far along we are.
local function advanceOrFinish(job, confirmed, total)
    active.stopIndex = confirmed + 1
    if active.stopIndex <= total then
        local coords = currentStopCoords(job)
        if not coords then return end
        setWaypoint(coords, ('%s stop %s/%s'):format(job.label, active.stopIndex, total))
        lib.notify({
            title = job.label,
            description = ('Go to stop %s of %s'):format(active.stopIndex, total),
            type = 'inform',
        })
        return
    end

    -- all stops done
    if job.sellCoords then
        active.phase = 'sell'
        setWaypoint(job.sellCoords, 'Sell / turn in')
        lib.notify({ title = job.label, description = 'Turn in your work at the marked location.', type = 'success' })
        return
    end

    if job.returnToDepot then
        active.phase = 'return'
        setWaypoint(vec3(job.depot.x, job.depot.y, job.depot.z), 'Return vehicle')
        lib.notify({ title = job.label, description = 'Return the work vehicle to the depot.', type = 'success' })
        return
    end

    -- The server resets us via hc-jobs:client:runComplete once it has paid.
    TriggerServerEvent('hc-jobs:server:completeRun', job.id)
end

local function tryCompleteCurrentStop()
    if active.phase ~= 'stops' or not active.jobId or active.awaiting then return end
    local job = getJobDef(active.jobId)
    if not job then return end
    local target = currentStopCoords(job)
    if not target then return end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    if #(coords - target) > 8.0 then
        lib.notify({ title = 'Jobs', description = 'Get closer to the stop.', type = 'error' })
        return
    end

    local labels = {
        delivery = 'Delivering package...',
        tow = 'Hooking vehicle...',
        fishing = 'Fishing...',
        mining = 'Mining ore...',
        taxi = 'Dropping off fare...',
        garbage = 'Collecting trash...',
    }

    if doProgress(labels[job.id] or 'Working...') then
        local pending = active.stopIndex
        active.awaiting = true
        TriggerServerEvent('hc-jobs:server:completeStop', job.id, active.stopIndices[pending])
        -- Fallback: if the server never answers (throttled, restarting), let the
        -- player try the stop again rather than leaving the job unusable.
        SetTimeout(10000, function()
            if active.awaiting and active.stopIndex == pending then
                active.awaiting = false
            end
        end)
    else
        lib.notify({ title = 'Jobs', description = 'Cancelled.', type = 'error' })
    end
end

local function trySellOrReturn()
    if not active.jobId then return end
    local job = getJobDef(active.jobId)
    if not job then return end
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    if active.phase == 'sell' and job.sellCoords then
        if #(coords - job.sellCoords) > 8.0 then
            lib.notify({ title = 'Jobs', description = 'Get closer to turn-in.', type = 'error' })
            return
        end
        if doProgress('Turning in...') then
            -- Stay on the job until the server confirms (hc-jobs:client:runComplete).
            TriggerServerEvent('hc-jobs:server:completeRun', job.id)
        end
        return
    end

    if active.phase == 'return' then
        local depot = vec3(job.depot.x, job.depot.y, job.depot.z)
        if #(coords - depot) > 12.0 then
            lib.notify({ title = 'Jobs', description = 'Return to the depot.', type = 'error' })
            return
        end
        if active.vehicle and DoesEntityExist(active.vehicle)
            and #(GetEntityCoords(active.vehicle) - depot) > Config.DepotDistance then
            lib.notify({ title = 'Jobs', description = 'Bring the work vehicle back to the depot.', type = 'error' })
            return
        end
        -- Stay on the job until the server confirms (hc-jobs:client:runComplete);
        -- if it refuses, the player can fix the problem and try again.
        TriggerServerEvent('hc-jobs:server:completeRun', job.id)
    end
end

local function openJobCenter()
    local options = {}
    if active.jobId then
        options[#options + 1] = {
            title = 'Cancel current job',
            description = active.label or active.jobId,
            onSelect = function()
                TriggerServerEvent('hc-jobs:server:cancelJob')
                resetActive()
                lib.notify({ title = 'Jobs', description = 'Job cancelled.', type = 'inform' })
            end,
        }
    end
    for _, job in ipairs(Config.Jobs) do
        options[#options + 1] = {
            title = job.label,
            description = ('%s | Pay ~$%s–$%s / run'):format(job.description, job.payMin, job.payMax),
            disabled = active.jobId ~= nil,
            onSelect = function()
                TriggerServerEvent('hc-jobs:server:startJob', job.id)
            end,
        }
    end
    lib.registerContext({ id = 'hc_job_center', title = Config.JobCenter.label, options = options })
    lib.showContext('hc_job_center')
end

RegisterNetEvent('hc-jobs:client:jobStarted', function(jobId, label, stopIndices, vehicleNetId, vehiclePlate)
    local job = getJobDef(jobId)
    if not job or type(stopIndices) ~= 'table' or #stopIndices == 0 then return end

    resetActive()
    active.jobId = jobId
    active.label = label
    active.stopIndices = stopIndices
    active.stopIndex = 1
    active.phase = 'stops'

    enterWorkVehicle(job, vehicleNetId, vehiclePlate)
    local first = currentStopCoords(job)
    if not first then return end
    setWaypoint(first, ('%s stop 1/%s'):format(label, #stopIndices))
    lib.notify({
        title = 'Heartless Jobs',
        description = ('Started %s — complete %s stops. Use [E] at each marker.'):format(label, #stopIndices),
        type = 'success',
        duration = 8000,
    })
end)

--- The server paid out: the run is over.
RegisterNetEvent('hc-jobs:client:runComplete', function(jobId)
    if active.jobId == jobId then resetActive() end
end)

--- The server refused the stop — let the player work it again.
RegisterNetEvent('hc-jobs:client:stopRejected', function(jobId)
    if active.jobId == jobId then
        active.awaiting = false
    end
end)

--- The server accepted the stop we just worked.
RegisterNetEvent('hc-jobs:client:stopConfirmed', function(jobId, confirmed, total)
    active.awaiting = false
    if active.jobId ~= jobId then return end
    local job = getJobDef(jobId)
    if not job then return end
    advanceOrFinish(job, confirmed, total)
end)

RegisterNetEvent('hc-jobs:client:forceStop', function()
    resetActive()
end)

CreateThread(function()
    local blip = AddBlipForCoord(Config.JobCenter.coords.x, Config.JobCenter.coords.y, Config.JobCenter.coords.z)
    SetBlipSprite(blip, 407)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.85)
    SetBlipColour(blip, 2)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.JobCenter.label)
    EndTextCommandSetBlipName(blip)

    exports.ox_target:addBoxZone({
        coords = Config.JobCenter.coords,
        size = vec3(2.0, 2.0, 2.5),
        rotation = 0,
        debug = false,
        options = {
            {
                name = 'hc_job_center',
                icon = 'fa-solid fa-briefcase',
                label = 'Open Job Center',
                onSelect = openJobCenter,
            },
        },
    })
end)

-- Interaction key while on job
CreateThread(function()
    while true do
        local sleep = 1000
        if active.jobId and active.phase ~= 'idle' then
            sleep = 0
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local prompt = false

            if active.phase == 'stops' then
                local job = getJobDef(active.jobId)
                local target = job and currentStopCoords(job) or nil
                if target and #(coords - target) < 15.0 then
                    prompt = true
                    lib.showTextUI('[E] Work this stop')
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        tryCompleteCurrentStop()
                    end
                end
            elseif active.phase == 'sell' or active.phase == 'return' then
                local job = getJobDef(active.jobId)
                local target = active.phase == 'sell' and job.sellCoords or vec3(job.depot.x, job.depot.y, job.depot.z)
                if target and #(coords - target) < 15.0 then
                    prompt = true
                    lib.showTextUI(active.phase == 'sell' and '[E] Turn in' or '[E] Return vehicle & get paid')
                    if IsControlJustReleased(0, 38) then
                        lib.hideTextUI()
                        trySellOrReturn()
                    end
                end
            end

            if not prompt then
                lib.hideTextUI()
            end
        else
            lib.hideTextUI()
        end
        Wait(sleep)
    end
end)
