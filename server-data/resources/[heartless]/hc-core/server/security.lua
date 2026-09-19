--[[
    Shared server-side guards for every hc-* resource.

    Rule for this codebase: the client may ASK for something, it may never
    ASSERT it. Anything that moves money, items, or a player's position has to
    be re-checked here, server side, before it happens.

    Distance checks stay local to each resource (a vector3 does not survive a
    cross-resource export cleanly) — see the `near()` helper at the top of each
    server/main.lua. This file owns the guards that only need plain values:
    rate limiting, abuse flagging, and the money audit trail.
]]

local rateBuckets = {}
local flagCounts = {}

--- Per-player, per-action throttle.
--- Returns true when the action is allowed, false when it is too soon.
---@param src number
---@param key string action name, e.g. 'job:start'
---@param ms? number minimum gap between calls
---@return boolean
function HCRateLimit(src, key, ms)
    ms = ms or (Config.Security and Config.Security.defaultCooldownMs) or 1000
    local bucket = rateBuckets[src]
    if not bucket then
        bucket = {}
        rateBuckets[src] = bucket
    end
    local t = GetGameTimer()
    local last = bucket[key]
    if last and (t - last) < ms then return false end
    bucket[key] = t
    return true
end

exports('RateLimit', HCRateLimit)

--- Record a rejected client claim. Repeat offenders get logged loudly so staff
--- can look at them; we do not auto-ban (false positives during a demo are worse
--- than a noisy log).
---@param src number
---@param reason string
function HCFlag(src, reason)
    local n = (flagCounts[src] or 0) + 1
    flagCounts[src] = n

    local name = GetPlayerName(src) or 'unknown'
    print(('^3[hc-security]^7 %s (%s) rejected: %s [%s this session]'):format(name, src, reason, n))

    local threshold = (Config.Security and Config.Security.flagThreshold) or 10
    if n == threshold then
        print(('^1[hc-security]^7 %s (%s) has hit %s rejections — review this player.'):format(name, src, n))
        HCLogMoney(src, 'security', 0, ('%s rejections, latest: %s'):format(n, reason))
    end
end

exports('Flag', HCFlag)

--- Audit trail for every payout / charge the hc-* scripts make.
--- Writes to hc_transaction_log and, if configured, mirrors to Discord.
---@param src number
---@param category string e.g. 'hc-job-delivery'
---@param amount number positive = player gained, negative = player paid
---@param detail? string
function HCLogMoney(src, category, amount, detail)
    local identifier, name = 'console', 'console'
    if src and src > 0 then
        name = GetPlayerName(src) or 'unknown'
        identifier = GetPlayerIdentifierByType and (GetPlayerIdentifierByType(src, 'license') or 'unknown') or 'unknown'
    end

    if Config.Debug then
        print(('^2[hc-money]^7 %s (%s) %s %s%s'):format(
            name, src or 0, category, amount >= 0 and '+$' or '-$', math.abs(amount)
        ))
    end

    pcall(function()
        MySQL.insert('INSERT INTO hc_transaction_log (identifier, player_name, category, amount, detail) VALUES (?, ?, ?, ?, ?)', {
            identifier, name, category, amount, detail,
        })
    end)

    local hook = Config.Security and Config.Security.moneyWebhook
    if hook and hook ~= '' and math.abs(amount) >= ((Config.Security and Config.Security.webhookMinAmount) or 25000) then
        PerformHttpRequest(hook, function() end, 'POST', json.encode({
            username = 'Heartless Ledger',
            embeds = { {
                title = category,
                description = ('**%s** (`%s`)\n%s$%s\n%s'):format(name, identifier, amount >= 0 and '+' or '-', math.abs(amount), detail or ''),
                color = amount >= 0 and 3066993 or 15158332,
            } },
        }), { ['Content-Type'] = 'application/json' })
    end
end

exports('LogMoney', HCLogMoney)

AddEventHandler('playerDropped', function()
    rateBuckets[source] = nil
    flagCounts[source] = nil
end)
