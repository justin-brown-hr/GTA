local QBCore = exports['qb-core']:GetCoreObject()

--[[
    The server owns the route.

    It picks which stops a run uses, hands the client only the indices, and
    confirms each stop one at a time after checking the player is actually
    standing there. The client can no longer "finish" a run by waiting out a
    timer — every stop has to be reached in the order the server handed out.
]]

--- [src] = { jobId, startedAt, stops = {indices}, progress = n, lastStopAt, paid }
local sessions = {}

local function getJob(id)
    for _, job in ipairs(Config.Jobs) do
        if job.id == id then return job end
    end
end

--- Server-side distance check.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.InteractDistance)
end

local function rateLimit(src, key, ms)
    return exports['hc-core']:RateLimit(src, key, ms)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'jobs:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

--- Pick Config.StopsPerRun distinct stop indices for this job.
local function pickStopIndices(job)
    local pool = {}
    for i = 1, #job.stops do pool[i] = i end
    local chosen = {}
    local need = math.min(Config.StopsPerRun, #pool)
    for _ = 1, need do
        local at = math.random(#pool)
        chosen[#chosen + 1] = pool[at]
        table.remove(pool, at)
    end
    return chosen
end

local function clearSession(src)
    sessions[src] = nil
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        Player.Functions.SetMetaData('hc_active_job', nil)
    end
end

RegisterNetEvent('hc-jobs:server:startJob', function(jobId)
    local src = source
    if not rateLimit(src, 'jobs:start', 2000) then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job = getJob(jobId)
    if not job then
        reject(src, 'start-badjob')
        return
    end

    if not near(src, Config.JobCenter.coords, Config.InteractDistance) then
        reject(src, 'start-distance', 'You have to be at the Job Center to sign on.')
        return
    end

    if sessions[src] then
        exports['hc-core']:Notify(src, 'Finish or cancel your current job first.', 'error')
        return
    end

    local stops = pickStopIndices(job)
    if #stops == 0 then
        reject(src, 'start-nostops', 'That job has no route configured.')
        return
    end

    sessions[src] = {
        jobId = job.id,
        startedAt = os.time(),
        stops = stops,
        progress = 0,
        lastStopAt = 0,
        paid = false,
    }
    Player.Functions.SetMetaData('hc_active_job', job.id)
    TriggerClientEvent('hc-jobs:client:jobStarted', src, job.id, job.label, stops)
end)

RegisterNetEvent('hc-jobs:server:cancelJob', function()
    clearSession(source)
end)

--- Confirm one stop. The client asks after its progress bar finishes; we only
--- agree if this is the next stop we handed out and the player is standing on it.
--- Every refusal answers the client too, so an honest player who gets rejected
--- (desync, walked off mid-bar) can retry instead of being stuck.
RegisterNetEvent('hc-jobs:server:completeStop', function(jobId, stopIndex)
    local src = source
    if not rateLimit(src, 'jobs:stop', 1500) then return end

    local function deny(reason, msg)
        reject(src, reason, msg)
        TriggerClientEvent('hc-jobs:client:stopRejected', src, jobId)
    end

    local session = sessions[src]
    if not session or session.jobId ~= jobId or session.paid then
        deny('stop-nosession', 'No active job run.')
        return
    end

    local job = getJob(jobId)
    if not job then
        deny('stop-badjob')
        return
    end

    stopIndex = tonumber(stopIndex)
    local expected = session.stops[session.progress + 1]
    if not stopIndex or stopIndex ~= expected then
        deny('stop-outoforder', 'That is not your next stop.')
        return
    end

    local coords = job.stops[stopIndex]
    if not near(src, coords, Config.InteractDistance) then
        deny('stop-distance', 'You are not at the stop.')
        return
    end

    -- The client runs a Config.ProgressMs progress bar per stop; anything much
    -- faster than that means the bar was skipped.
    local minGap = math.floor((Config.ProgressMs / 1000) * 0.8)
    if session.lastStopAt > 0 and (os.time() - session.lastStopAt) < minGap then
        deny('stop-toofast', 'Slow down — work the stop properly.')
        return
    end

    session.progress = session.progress + 1
    session.lastStopAt = os.time()
    TriggerClientEvent('hc-jobs:client:stopConfirmed', src, job.id, session.progress, #session.stops)
end)

RegisterNetEvent('hc-jobs:server:completeRun', function(jobId)
    local src = source
    if not rateLimit(src, 'jobs:complete', 2000) then return end

    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job = getJob(jobId)
    if not job then return end

    local session = sessions[src]
    if not session or session.jobId ~= job.id or session.paid then
        reject(src, 'run-nosession', 'No valid job run to complete.')
        return
    end

    if session.progress < #session.stops then
        reject(src, 'run-incomplete', ('You still have %s stops left.'):format(#session.stops - session.progress))
        return
    end

    -- Turn-in / depot return has to happen where the job says it does.
    if job.sellCoords then
        if not near(src, job.sellCoords, Config.InteractDistance) then
            reject(src, 'run-selldistance', 'Turn your work in at the marked location.')
            return
        end
    elseif job.returnToDepot then
        local depot = vec3(job.depot.x, job.depot.y, job.depot.z)
        if not near(src, depot, Config.DepotDistance) then
            reject(src, 'run-depotdistance', 'Return the work vehicle to the depot.')
            return
        end
    end

    local minSeconds = math.max(15, #session.stops * math.floor(Config.ProgressMs / 1000))
    if (os.time() - session.startedAt) < minSeconds then
        reject(src, 'run-toofast', 'That was too fast — finish the route properly.')
        return
    end

    session.paid = true

    local pay = math.random(job.payMin, job.payMax)
    local mult = 1.0
    local ok, cfg = pcall(function()
        return exports['hc-core']:GetConfig()
    end)
    if ok and cfg and cfg.Economy then
        mult = cfg.Economy.jobPayMultiplier or 1.0
    end
    pay = math.floor(pay * mult)

    Player.Functions.AddMoney('cash', pay, 'hc-job-' .. job.id)
    exports['hc-core']:LogMoney(src, 'hc-job-' .. job.id, pay, ('%s stops'):format(#session.stops))
    exports['hc-core']:Notify(src, ('You earned $%s from %s'):format(pay, job.label), 'success')
    clearSession(src)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
end)

QBCore.Commands.Add('canceljob', 'Cancel your Heartless civilian job', {}, false, function(source)
    clearSession(source)
    TriggerClientEvent('hc-jobs:client:forceStop', source)
    exports['hc-core']:Notify(source, 'Job cancelled.', 'inform')
end)
