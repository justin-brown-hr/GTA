fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hc-core'
author 'Heartless City RP'
description 'Shared config, branding, and helpers for Heartless City RP'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qb-core',
}
