local QBCore = exports['qb-core']:GetCoreObject()

local active = {
    jobId = nil,
    label = nil,
    vehicle = nil,
    blip = nil,
    stopIndex = 0,
    stops = {},
    phase = 'idle', -- idle | stops | sell | return
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

local function deleteJobVehicle()
    if active.vehicle and DoesEntityExist(active.vehicle) then
        DeleteEntity(active.vehicle)
    end
    active.vehicle = nil
end

local function resetActive()
    clearBlip()
    deleteJobVehicle()
    active.jobId = nil
    active.label = nil
    active.stopIndex = 0
    active.stops = {}
    active.phase = 'idle'
end

local function getJobDef(id)
    for _, j in ipairs(Config.Jobs) do
        if j.id == id then return j end
    end
end

local function pickStops(job)
    local pool = {}
    for i = 1, #job.stops do pool[i] = job.stops[i] end
    local chosen = {}
    local need = math.min(Config.StopsPerRun, #pool)
    for _ = 1, need do
        local idx = math.random(#pool)
        chosen[#chosen + 1] = pool[idx]
        table.remove(pool, idx)
    end
    return chosen
end

local function spawnJobVehicle(job)
    if not job.vehicle then return true end
    local d = job.depot
    lib.requestModel(job.vehicle)
    local veh = CreateVehicle(joaat(job.vehicle), d.x, d.y, d.z, d.w, true, false)
    SetVehicleOnGroundProperly(veh)
    SetVehicleNumberPlateText(veh, 'HCJOB')
    SetEntityAsMissionEntity(veh, true, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
    SetModelAsNoLongerNeeded(job.vehicle)
    active.vehicle = veh
    TriggerEvent('vehiclekeys:client:SetOwner', QBCore.Functions.GetPlate(veh))
    return true
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

local function advanceOrFinish(job)
    active.stopIndex = active.stopIndex + 1
    if active.stopIndex <= #active.stops then
        setWaypoint(active.stops[active.stopIndex], ('%s stop %s/%s'):format(job.label, active.stopIndex, #active.stops))
        lib.notify({
            title = job.label,
            description = ('Go to stop %s of %s'):format(active.stopIndex, #active.stops),
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

    TriggerServerEvent('hc-jobs:server:completeRun', job.id)
    resetActive()
end

local function tryCompleteCurrentStop()
    if active.phase ~= 'stops' or not active.jobId then return end
    local job = getJobDef(active.jobId)
    if not job then return end
    local target = active.stops[active.stopIndex]
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
        advanceOrFinish(job)
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
            TriggerServerEvent('hc-jobs:server:completeRun', job.id)
            resetActive()
        end
        return
    end

    if active.phase == 'return' then
        local depot = vec3(job.depot.x, job.depot.y, job.depot.z)
        if #(coords - depot) > 12.0 then
            lib.notify({ title = 'Jobs', description = 'Return to the depot.', type = 'error' })
            return
        end
        deleteJobVehicle()
        TriggerServerEvent('hc-jobs:server:completeRun', job.id)
        resetActive()
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

RegisterNetEvent('hc-jobs:client:jobStarted', function(jobId, label)
    local job = getJobDef(jobId)
    if not job then return end

    resetActive()
    active.jobId = jobId
    active.label = label
    active.stops = pickStops(job)
    active.stopIndex = 1
    active.phase = 'stops'

    spawnJobVehicle(job)
    setWaypoint(active.stops[1], ('%s stop 1/%s'):format(label, #active.stops))
    lib.notify({
        title = 'Heartless Jobs',
        description = ('Started %s — complete %s stops. Use [E] at each marker.'):format(label, #active.stops),
        type = 'success',
        duration = 8000,
    })
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
    SetBlipAsShortRange(blip, true)
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
                local target = active.stops[active.stopIndex]
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
