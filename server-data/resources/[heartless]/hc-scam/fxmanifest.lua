fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hc-scam'
author 'Heartless City RP'
description 'Scamming equipment and illegal tool economy'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

dependencies {
    'qb-core',
    'oxmysql',
    'ox_lib',
    'ox_inventory',
    'hc-core',
}
