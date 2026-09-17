local QBCore = exports['qb-core']:GetCoreObject()

--- Active job sessions: [src] = { jobId, startedAt, stopsDone }
local sessions = {}

local function getJob(id)
    for _, job in ipairs(Config.Jobs) do
        if job.id == id then return job end
    end
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
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job = getJob(jobId)
    if not job then return end

    if sessions[src] then
        exports['hc-core']:Notify(src, 'Finish or cancel your current job first.', 'error')
        return
    end

    sessions[src] = {
        jobId = job.id,
        startedAt = os.time(),
        paid = false,
    }
    Player.Functions.SetMetaData('hc_active_job', job.id)
    TriggerClientEvent('hc-jobs:client:jobStarted', src, job.id, job.label)
end)

RegisterNetEvent('hc-jobs:server:cancelJob', function()
    local src = source
    clearSession(src)
end)

RegisterNetEvent('hc-jobs:server:completeRun', function(jobId)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local job = getJob(jobId)
    if not job then return end

    local session = sessions[src]
    if not session or session.jobId ~= job.id or session.paid then
        exports['hc-core']:Notify(src, 'No valid job run to complete.', 'error')
        return
    end

    -- Anti-spam: require at least ~stops * progress time
    local minSeconds = math.max(15, (Config.StopsPerRun or 3) * 4)
    if (os.time() - session.startedAt) < minSeconds then
        exports['hc-core']:Notify(src, 'That was too fast — finish the route properly.', 'error')
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
