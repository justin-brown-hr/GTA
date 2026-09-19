Config = {}

Config.ServerName = 'Heartless City RP'
Config.DiscordInvite = 'https://discord.gg/dAhv96zVf'
Config.Debug = true

-- Branding shown in notifies / help text
Config.Brand = {
    short = 'HCR',
    color = '#C41E3A', -- heartless red accent
}

-- City feel: serious RP defaults
Config.Rules = {
    crimNeedsPdChance = true,
    newPlayerProtectedMinutes = 30,
}

--[[
  Server-side abuse guards. Every hc-* resource re-checks the client's claims
  against these before paying out. See hc-core/server/security.lua.
]]
Config.Security = {
    -- Minimum gap between two calls of the same action by the same player.
    defaultCooldownMs = 1000,
    -- How many rejected claims before a player is called out in the console.
    flagThreshold = 10,
    -- Optional Discord webhook for large money movements (leave '' to disable).
    moneyWebhook = '',
    webhookMinAmount = 25000,
    -- How close a player must actually be to a shop / desk / job stop.
    interactDistance = 12.0,
}

-- Shared money sinks / multipliers (other resources may read these)
Config.Economy = {
    jobPayMultiplier = 1.0,
    drugSellMultiplier = 1.0,
    heistPayoutMultiplier = 1.0,
    businessIncomeMultiplier = 1.0,
}
