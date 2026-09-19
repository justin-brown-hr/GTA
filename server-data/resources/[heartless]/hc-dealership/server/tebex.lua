local QBCore = exports['qb-core']:GetCoreObject()

--[[
    Tebex → in-game vehicle delivery.

    Tebex runs its commands the moment money changes hands. Most people buy on
    the website while they are NOT in game, so a grant that requires the buyer
    to be online loses the sale: the client keeps the money and the customer
    gets nothing.

    So a grant is never "give a car now". It is:

        1. record the purchase as pending (idempotent on transaction_id)
        2. deliver it if the buyer is online right now
        3. otherwise deliver it the next time that character loads

    A purchase can only ever produce one car, no matter how many times Tebex
    retries the command or a staff member pastes it.
]]

local PENDING, DELIVERED = 'pending', 'delivered'

--- Find an exclusive vehicle by spawn model OR by Tebex package id, so the
--- store can be configured with whichever is less error-prone to type.
---@return table|nil
local function findExclusive(ref)
    if type(ref) ~= 'string' then return end
    local needle = ref:lower()
    for _, v in ipairs(Config.ExclusiveLot.vehicles) do
        if v.model:lower() == needle then return v end
        if v.tebexPackageId and v.tebexPackageId:lower() == needle then return v end
    end
end

exports('FindExclusive', findExclusive)

--- Every identifier a connected player has, lowercased.
local function identifiersFor(src)
    local list = {}
    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        list[#list + 1] = id:lower()
    end
    return list
end

--[[
    Work out who a grant belongs to.

    Tebex's {id} placeholder can be a FiveM license, a Steam id, a Discord id or
    a server id depending on how the store is set up, and a citizenid is what
    staff will type by hand. Accept all of them.

    Returns: citizenid (may be nil), identifier (may be nil), online source.
    At least one of citizenid / identifier is always set on success.
]]
---@return string|nil citizenid, string|nil identifier, number|nil src
local function resolveTarget(arg)
    if not arg or arg == '' then return end

    -- 1. Server id — only meaningful while they are connected.
    local sid = tonumber(arg)
    if sid then
        local Player = QBCore.Functions.GetPlayer(sid)
        if Player then
            return Player.PlayerData.citizenid, nil, sid
        end
        print(('[hc-dealership] Server id %s is not online — use a citizenid or a license identifier instead.'):format(sid))
        return
    end

    -- 2. An identifier (license:..., steam:..., discord:..., fivem:...).
    if arg:find(':') then
        local identifier = arg:lower()
        for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
            for _, id in ipairs(identifiersFor(playerId)) do
                if id == identifier then
                    local Player = QBCore.Functions.GetPlayer(playerId)
                    if Player then
                        return Player.PlayerData.citizenid, identifier, playerId
                    end
                end
            end
        end
        -- Not online: queue against the raw identifier and match it on join.
        return nil, identifier, nil
    end

    -- 3. A citizenid. Verify it exists so a typo does not vanish into the queue.
    local row = MySQL.single.await('SELECT citizenid FROM players WHERE citizenid = ? LIMIT 1', { arg })
    if not row then
        print(('[hc-dealership] No character with citizenid %s'):format(arg))
        return
    end
    local Player = QBCore.Functions.GetPlayerByCitizenId(arg)
    return arg, nil, Player and Player.PlayerData.source or nil
end

--- Hand a queued grant to a loaded character.
--- Returns true only if THIS call delivered it.
---@return boolean
local function deliverGrant(row, Player)
    local plate = HCUniquePlate()
    if not plate then
        print('[hc-dealership] Could not issue a unique plate — grant stays pending.')
        return false
    end

    -- Claim the row first. If another thread (a second login, a retry sweep)
    -- already took it, affectedRows is 0 and we stop — one purchase, one car.
    local claimed = MySQL.update.await(
        ('UPDATE hc_tebex_grants SET status = ?, citizenid = ?, plate = ?, delivered_at = NOW() WHERE id = ? AND status = ?'),
        { DELIVERED, Player.PlayerData.citizenid, plate, row.id, PENDING }
    )
    if not claimed or claimed == 0 then return false end

    if not HCInsertVehicle(Player.PlayerData.license, Player.PlayerData.citizenid, row.model, plate, Config.DefaultGarage) then
        -- Put it back so the next login retries instead of eating the purchase.
        MySQL.update.await('UPDATE hc_tebex_grants SET status = ?, plate = NULL, delivered_at = NULL WHERE id = ?', { PENDING, row.id })
        print(('^1[hc-dealership]^7 delivery failed for %s (%s) — left pending for retry.'):format(Player.PlayerData.citizenid, row.model))
        return false
    end

    local exclusive = findExclusive(row.model)
    local label = exclusive and exclusive.label or row.model
    local src = Player.PlayerData.source

    exports['hc-core']:LogMoney(src, 'hc-tebex-grant', 0, ('%s → %s (%s) tx=%s'):format(row.model, Player.PlayerData.citizenid, plate, row.transaction_id))
    print(('^2[hc-dealership]^7 delivered %s to %s (plate %s, tx %s)'):format(row.model, Player.PlayerData.citizenid, plate, row.transaction_id))

    -- Drop it at the lot if they are standing there; otherwise it is waiting in
    -- the garage. Spawning a car under someone mid-scene is worse than a notify.
    local ped = GetPlayerPed(src)
    local atLot = ped and ped ~= 0 and #(GetEntityCoords(ped) - Config.ExclusiveLot.coords) <= Config.LotDistance
    if atLot then
        TriggerClientEvent('hc-dealership:client:spawnPurchased', src, row.model, plate, true)
        exports['hc-core']:Notify(src, ('Exclusive delivered: %s'):format(label), 'success', 10000)
    else
        exports['hc-core']:Notify(src, ('Exclusive delivered: %s — parked in your garage (plate %s).'):format(label, plate), 'success', 12000)
    end
    return true
end

--- Deliver everything queued for a character that just loaded in.
local function deliverPendingFor(Player)
    local src = Player.PlayerData.source
    local ids = identifiersFor(src)

    local placeholders = {}
    local params = { PENDING, Player.PlayerData.citizenid }
    for _, id in ipairs(ids) do
        placeholders[#placeholders + 1] = '?'
        params[#params + 1] = id
    end

    local sql = 'SELECT id, model, transaction_id FROM hc_tebex_grants WHERE status = ? AND (citizenid = ?'
    if #placeholders > 0 then
        sql = sql .. (' OR grant_identifier IN (%s)'):format(table.concat(placeholders, ','))
    end
    sql = sql .. ') ORDER BY id ASC'

    local rows = MySQL.query.await(sql, params)
    if not rows or #rows == 0 then return end

    print(('[hc-dealership] %s pending grant(s) for %s'):format(#rows, Player.PlayerData.citizenid))
    for _, row in ipairs(rows) do
        deliverGrant(row, Player)
        Wait(250) -- stagger so several cars do not all spawn on the same frame
    end
end

AddEventHandler('QBCore:Server:PlayerLoaded', function(Player)
    CreateThread(function()
        Wait(Config.GrantDeliveryDelayMs)
        deliverPendingFor(Player)
    end)
end)

--[[
    Queue a purchase.

    This is the only path that creates a grant row, and it is idempotent: the
    same transaction_id can be sent any number of times and still yields one car.
]]
---@return boolean queued
local function queueGrant(targetArg, vehicleRef, txRef, sourceLabel)
    local exclusive = findExclusive(vehicleRef)
    if not exclusive then
        print(('[hc-dealership] "%s" is not an exclusive model or package id. Known: %s'):format(
            tostring(vehicleRef), (function()
                local names = {}
                for _, v in ipairs(Config.ExclusiveLot.vehicles) do
                    names[#names + 1] = ('%s (%s)'):format(v.model, v.tebexPackageId or 'no package')
                end
                return table.concat(names, ', ')
            end)()
        ))
        return false
    end

    local citizenid, identifier, src = resolveTarget(targetArg)
    if not citizenid and not identifier then
        print(('[hc-dealership] Could not resolve "%s" to a player.'):format(tostring(targetArg)))
        return false
    end

    local txId = txRef
    if not txId or txId == '' then
        -- Manual grants get a synthetic reference so the log still ties back to
        -- a single event, but they are NOT deduplicated against each other.
        txId = ('manual-%s-%s-%s'):format(sourceLabel or 'staff', exclusive.model, os.time())
    end

    local existing = MySQL.single.await('SELECT id, status FROM hc_tebex_grants WHERE transaction_id = ? LIMIT 1', { txId })
    if existing then
        print(('[hc-dealership] Transaction %s already recorded (%s) — ignoring duplicate.'):format(txId, existing.status))
        return true
    end

    local ok = pcall(function()
        MySQL.insert.await(
            'INSERT INTO hc_tebex_grants (transaction_id, citizenid, grant_identifier, model, package_id, status, payload) VALUES (?, ?, ?, ?, ?, ?, ?)',
            { txId, citizenid, identifier, exclusive.model, exclusive.tebexPackageId, PENDING, sourceLabel }
        )
    end)
    if not ok then
        -- Unique index on transaction_id fired: another call won the race.
        print(('[hc-dealership] Transaction %s already queued by a parallel call.'):format(txId))
        return true
    end

    print(('^2[hc-dealership]^7 queued %s for %s (tx %s)'):format(exclusive.model, citizenid or identifier, txId))

    if src then
        local Player = QBCore.Functions.GetPlayer(src)
        if Player then
            local row = MySQL.single.await('SELECT id, model, transaction_id FROM hc_tebex_grants WHERE transaction_id = ?', { txId })
            if row then deliverGrant(row, Player) end
        end
    else
        print('[hc-dealership] Buyer is offline — it will be delivered on their next login.')
    end
    return true
end

exports('QueueGrant', queueGrant)

--[[ ---------------------------------------------------------------------
     Console / Tebex commands
     ------------------------------------------------------------------ ]]

--- Tebex store command:
---   hc_tebex_grant {id} CyberTruckV {transaction}
--- Console / RCON only — an in-game admin cannot run this even with 'command allow'.
RegisterCommand('hc_tebex_grant', function(source, args)
    if source ~= 0 then return end
    if not args[1] or not args[2] then
        print('[hc-dealership] Usage: hc_tebex_grant <serverId|citizenid|identifier> <model|packageId> [transactionId]')
        return
    end
    -- Own thread: this does database work and must be able to yield.
    CreateThread(function()
        queueGrant(args[1], args[2], args[3], 'tebex')
    end)
end, true)

--- What is still waiting to be delivered.
RegisterCommand('hc_tebex_pending', function(source)
    if source ~= 0 then return end
    CreateThread(function()
        local rows = MySQL.query.await(
            'SELECT transaction_id, citizenid, grant_identifier, model, created_at FROM hc_tebex_grants WHERE status = ? ORDER BY id ASC',
            { PENDING }
        )
        if not rows or #rows == 0 then
            print('[hc-dealership] No pending grants.')
            return
        end
        print(('[hc-dealership] %s pending grant(s):'):format(#rows))
        for _, r in ipairs(rows) do
            -- oxmysql hands TIMESTAMP columns back as epoch milliseconds.
            local queued = tonumber(r.created_at)
            queued = queued and os.date('%Y-%m-%d %H:%M', math.floor(queued / 1000)) or tostring(r.created_at)
            print(('  %s  %-14s  %s  queued %s'):format(
                r.transaction_id, r.model, r.citizenid or r.grant_identifier or '?', queued))
        end
    end)
end, true)

--- Force a delivery sweep for everyone currently online (after fixing a bad
--- model name, or if a delivery failed while the DB was down).
RegisterCommand('hc_tebex_retry', function(source)
    if source ~= 0 then return end
    CreateThread(function()
        local n = 0
        for _, playerId in pairs(QBCore.Functions.GetPlayers()) do
            local Player = QBCore.Functions.GetPlayer(playerId)
            if Player then
                deliverPendingFor(Player)
                n = n + 1
            end
        end
        print(('[hc-dealership] Retry sweep ran for %s online player(s).'):format(n))
    end)
end, true)

--- In-game staff grant for support / comps. Needs the 'hc.grant' ace, which is
--- NOT the same as generic admin — exclusive cars are real money.
QBCore.Commands.Add('hcgrant', 'Grant an exclusive vehicle (staff)', {
    { name = 'id', help = 'server id of the player' },
    { name = 'model', help = 'exclusive model or package id' },
}, true, function(source, args)
    if not IsPlayerAceAllowed(source, 'hc.grant') then
        exports['hc-core']:Notify(source, 'You do not have permission for that.', 'error')
        exports['hc-core']:Flag(source, 'dealer:hcgrant-noace')
        return
    end
    local staff = GetPlayerName(source)
    local src = source
    CreateThread(function()
        if queueGrant(args[1], args[2], nil, ('staff:%s'):format(staff)) then
            exports['hc-core']:Notify(src, 'Grant queued.', 'success')
            print(('^3[hc-dealership]^7 MANUAL GRANT by %s (%s): %s → %s'):format(staff, src, args[2], args[1]))
        else
            exports['hc-core']:Notify(src, 'Grant failed — check the server console.', 'error')
        end
    end)
end, 'admin')
