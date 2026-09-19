local QBCore = exports['qb-core']:GetCoreObject()

--- Server-side distance check — the desk and the stash are physical places.
local function near(src, coords, dist)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not coords then return false end
    return #(GetEntityCoords(ped) - coords) <= (dist or Config.InteractDistance)
end

local function rateLimit(src, key, ms)
    return exports['hc-core']:RateLimit(src, key, ms)
end

local function reject(src, reason, msg)
    exports['hc-core']:Flag(src, 'business:' .. reason)
    if msg then exports['hc-core']:Notify(src, msg, 'error') end
end

--- Money coming from a client is a suggestion. Force it to a whole, positive,
--- sane number before it touches a balance.
---@return number|nil
local function sanitizeAmount(src, raw)
    local amount = math.floor(tonumber(raw) or 0)
    if amount <= 0 then return nil end
    if amount > Config.MaxTransaction then
        reject(src, 'amount-toolarge', ('Maximum per transaction is $%s.'):format(Config.MaxTransaction))
        return nil
    end
    return amount
end

local function getDef(key)
    for _, b in ipairs(Config.Businesses) do
        if b.key == key then return b end
    end
end

local function decodeEmployees(row)
    if not row or not row.employees or row.employees == '' then return {} end
    local ok, data = pcall(json.decode, row.employees)
    if ok and type(data) == 'table' then return data end
    return {}
end

local function isEmployee(employees, citizenid)
    for _, id in ipairs(employees) do
        if id == citizenid then return true end
    end
    return false
end

local function canAccess(row, citizenid)
    if not row then return false, false, false end
    local employees = decodeEmployees(row)
    local owner = row.owner_citizenid == citizenid
    local employee = isEmployee(employees, citizenid)
    return owner or employee, owner, employee
end

RegisterNetEvent('hc-business:server:openDesk', function(key)
    local src = source
    if not rateLimit(src, 'business:desk', 500) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local def = getDef(key)
    if not def then return end
    if not near(src, def.coords) then
        reject(src, 'desk-distance', 'You are not at that business.')
        return
    end

    local row = MySQL.single.await('SELECT * FROM hc_businesses WHERE business_key = ?', { key })
    local owner = row and row.owner_citizenid or nil
    local employees = decodeEmployees(row)
    local _, isOwner, isEmployee = canAccess(row, Player.PlayerData.citizenid)

    TriggerClientEvent('hc-business:client:showDesk', src, {
        key = key,
        label = def.label,
        price = def.price,
        owner = owner,
        isOwner = isOwner,
        isEmployee = isEmployee,
        balance = row and row.balance or 0,
        employeeCount = #employees,
    })
end)

RegisterNetEvent('hc-business:server:buy', function(key)
    local src = source
    if not rateLimit(src, 'business:buy', 3000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local def = getDef(key)
    if not def then return end
    if not near(src, def.coords) then
        reject(src, 'buy-distance', 'You have to be at the business to buy it.')
        return
    end

    local row = MySQL.single.await('SELECT owner_citizenid FROM hc_businesses WHERE business_key = ?', { key })
    if row and row.owner_citizenid and row.owner_citizenid ~= '' then
        exports['hc-core']:Notify(src, 'This business is already owned.', 'error')
        return
    end

    if not Player.Functions.RemoveMoney('bank', def.price, 'hc-business-buy') then
        exports['hc-core']:Notify(src, 'Not enough money.', 'error')
        return
    end

    -- Claim it in one conditional write so two simultaneous buyers cannot both
    -- end up owning it. The loser gets their money straight back.
    MySQL.query.await(
        'INSERT IGNORE INTO hc_businesses (business_key, label, price, balance, employees) VALUES (?, ?, ?, 0, ?)',
        { key, def.label, def.price, '[]' }
    )
    local claimed = MySQL.update.await(
        [[UPDATE hc_businesses SET owner_citizenid = ?, employees = '[]'
          WHERE business_key = ? AND (owner_citizenid IS NULL OR owner_citizenid = '')]],
        { Player.PlayerData.citizenid, key }
    )

    if not claimed or claimed == 0 then
        Player.Functions.AddMoney('bank', def.price, 'hc-business-buy-refund')
        exports['hc-core']:Notify(src, 'Someone bought it first — you were refunded.', 'error')
        return
    end

    exports['hc-core']:LogMoney(src, 'hc-business-buy', -def.price, def.label)
    exports['hc-core']:Notify(src, ('You bought %s!'):format(def.label), 'success')
end)

RegisterNetEvent('hc-business:server:deposit', function(key, amount)
    local src = source
    if not rateLimit(src, 'business:deposit', 1000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local def = getDef(key)
    if not def then return end
    if not near(src, def.coords) then
        reject(src, 'deposit-distance', 'You are not at the business desk.')
        return
    end

    amount = sanitizeAmount(src, amount)
    if not amount then return end

    local row = MySQL.single.await('SELECT owner_citizenid FROM hc_businesses WHERE business_key = ?', { key })
    if not row or row.owner_citizenid ~= Player.PlayerData.citizenid then
        reject(src, 'deposit-notowner')
        return
    end

    if not Player.Functions.RemoveMoney('bank', amount, 'hc-business-deposit') then
        exports['hc-core']:Notify(src, 'Not enough bank money.', 'error')
        return
    end

    MySQL.update.await('UPDATE hc_businesses SET balance = balance + ? WHERE business_key = ?', { amount, key })
    exports['hc-core']:LogMoney(src, 'hc-business-deposit', -amount, key)
    exports['hc-core']:Notify(src, ('Deposited $%s'):format(amount), 'success')
end)

RegisterNetEvent('hc-business:server:withdraw', function(key, amount)
    local src = source
    if not rateLimit(src, 'business:withdraw', 1000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local def = getDef(key)
    if not def then return end
    if not near(src, def.coords) then
        reject(src, 'withdraw-distance', 'You are not at the business desk.')
        return
    end

    amount = sanitizeAmount(src, amount)
    if not amount then return end

    -- Ownership, funds and the debit all happen in ONE conditional statement.
    -- Reading the balance and then writing it lets two parallel withdrawals
    -- both pass the check and drain the business twice.
    local affected = MySQL.update.await(
        [[UPDATE hc_businesses SET balance = balance - ?
          WHERE business_key = ? AND owner_citizenid = ? AND balance >= ?]],
        { amount, key, Player.PlayerData.citizenid, amount }
    )

    if not affected or affected == 0 then
        exports['hc-core']:Notify(src, 'Not your business, or the balance is too low.', 'error')
        return
    end

    Player.Functions.AddMoney('bank', amount, 'hc-business-withdraw')
    exports['hc-core']:LogMoney(src, 'hc-business-withdraw', amount, key)
    exports['hc-core']:Notify(src, ('Withdrew $%s'):format(amount), 'success')
end)

RegisterNetEvent('hc-business:server:hire', function(key, targetId)
    local src = source
    if not rateLimit(src, 'business:hire', 1000) then return end
    local def = getDef(key)
    if not def then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Player or not Target then
        exports['hc-core']:Notify(src, 'Player not found.', 'error')
        return
    end
    if not near(src, def.coords) then
        reject(src, 'hire-distance', 'You are not at the business desk.')
        return
    end

    local row = MySQL.single.await('SELECT * FROM hc_businesses WHERE business_key = ?', { key })
    if not row or row.owner_citizenid ~= Player.PlayerData.citizenid then return end

    local employees = decodeEmployees(row)
    if #employees >= Config.MaxEmployees then
        exports['hc-core']:Notify(src, 'Employee limit reached.', 'error')
        return
    end
    if Target.PlayerData.citizenid == Player.PlayerData.citizenid then return end
    if isEmployee(employees, Target.PlayerData.citizenid) then
        exports['hc-core']:Notify(src, 'Already hired.', 'error')
        return
    end

    employees[#employees + 1] = Target.PlayerData.citizenid
    MySQL.update.await('UPDATE hc_businesses SET employees = ? WHERE business_key = ?', { json.encode(employees), key })
    exports['hc-core']:Notify(src, 'Employee hired.', 'success')
    exports['hc-core']:Notify(Target.PlayerData.source, ('You were hired at %s'):format(row.label), 'success')
end)

RegisterNetEvent('hc-business:server:fire', function(key, targetId)
    local src = source
    if not rateLimit(src, 'business:fire', 1000) then return end
    local def = getDef(key)
    if not def then return end

    local Player = QBCore.Functions.GetPlayer(src)
    local Target = QBCore.Functions.GetPlayer(tonumber(targetId))
    if not Player then return end
    if not near(src, def.coords) then
        reject(src, 'fire-distance', 'You are not at the business desk.')
        return
    end

    local row = MySQL.single.await('SELECT * FROM hc_businesses WHERE business_key = ?', { key })
    if not row or row.owner_citizenid ~= Player.PlayerData.citizenid then return end

    local citizenid = Target and Target.PlayerData.citizenid or nil
    if not citizenid then
        exports['hc-core']:Notify(src, 'Player must be online to fire by server ID (M1).', 'error')
        return
    end

    local employees = decodeEmployees(row)
    local nextList = {}
    for _, id in ipairs(employees) do
        if id ~= citizenid then nextList[#nextList + 1] = id end
    end
    MySQL.update.await('UPDATE hc_businesses SET employees = ? WHERE business_key = ?', { json.encode(nextList), key })
    exports['hc-core']:Notify(src, 'Employee fired.', 'inform')
    if Target then
        exports['hc-core']:Notify(Target.PlayerData.source, ('You were fired from %s'):format(row.label), 'error')
    end
end)

RegisterNetEvent('hc-business:server:sell', function(key)
    local src = source
    if not rateLimit(src, 'business:sell', 3000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local def = getDef(key)
    if not def then return end
    if not near(src, def.coords) then
        reject(src, 'sell-distance', 'You are not at the business desk.')
        return
    end

    local row = MySQL.single.await('SELECT balance, owner_citizenid FROM hc_businesses WHERE business_key = ?', { key })
    if not row or row.owner_citizenid ~= Player.PlayerData.citizenid then
        reject(src, 'sell-notowner')
        return
    end

    -- Release ownership first, and only pay out if THIS call is the one that
    -- released it — otherwise a double-click pays the refund twice.
    local released = MySQL.update.await(
        [[UPDATE hc_businesses SET owner_citizenid = NULL, balance = 0, employees = '[]'
          WHERE business_key = ? AND owner_citizenid = ?]],
        { key, Player.PlayerData.citizenid }
    )
    if not released or released == 0 then return end

    local refund = math.floor(def.price * 0.5) + (row.balance or 0)
    Player.Functions.AddMoney('bank', refund, 'hc-business-sell')
    exports['hc-core']:LogMoney(src, 'hc-business-sell', refund, def.label)
    exports['hc-core']:Notify(src, ('Sold business for $%s'):format(refund), 'success')
end)

RegisterNetEvent('hc-business:server:openStash', function(key)
    local src = source
    if not rateLimit(src, 'business:stash', 1000) then return end
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end
    local def = getDef(key)
    if not def then return end
    if not near(src, def.stashCoords or def.coords) then
        reject(src, 'stash-distance', 'You are not at the stash.')
        return
    end

    local row = MySQL.single.await('SELECT * FROM hc_businesses WHERE business_key = ?', { key })
    local allowed = canAccess(row, Player.PlayerData.citizenid)
    if not allowed then
        exports['hc-core']:Notify(src, 'No access to this stash.', 'error')
        return
    end

    local stashId = 'hc_biz_' .. key
    exports.ox_inventory:RegisterStash(stashId, def.label .. ' Stash', Config.StashSlots, Config.StashWeight)
    TriggerClientEvent('hc-business:client:openStash', src, stashId)
end)

-- Passive income for online owners
CreateThread(function()
    if not Config.PassiveIncome.enabled then return end
    local waitMs = (Config.PassiveIncome.intervalMinutes or 30) * 60 * 1000
    while true do
        Wait(waitMs)
        local rows = MySQL.query.await('SELECT business_key, owner_citizenid, label FROM hc_businesses WHERE owner_citizenid IS NOT NULL')
        if rows then
            for _, row in ipairs(rows) do
                local def = getDef(row.business_key)
                if def then
                    local amount = Config.PassiveIncome.amounts[def.type] or 150
                    local mult = 1.0
                    local ok, cfg = pcall(function() return exports['hc-core']:GetConfig() end)
                    if ok and cfg and cfg.Economy then
                        mult = cfg.Economy.businessIncomeMultiplier or 1.0
                    end
                    amount = math.floor(amount * mult)
                    MySQL.update.await('UPDATE hc_businesses SET balance = balance + ? WHERE business_key = ?', { amount, row.business_key })
                    local owner = QBCore.Functions.GetPlayerByCitizenId(row.owner_citizenid)
                    if owner then
                        exports['hc-core']:Notify(owner.PlayerData.source, ('%s earned $%s'):format(row.label, amount), 'success')
                    end
                end
            end
        end
    end
end)
