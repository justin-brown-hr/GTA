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

-- Shared money sinks / multipliers (other resources may read these)
Config.Economy = {
    jobPayMultiplier = 1.0,
    drugSellMultiplier = 1.0,
    heistPayoutMultiplier = 1.0,
    businessIncomeMultiplier = 1.0,
}
