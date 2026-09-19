fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hc-dealership'
author 'Heartless City RP'
description 'Public dealership + exclusive Tebex real-money cars'
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
    'server/vehicles.lua',
    'server/main.lua',
    'server/tebex.lua',
}

dependencies {
    'qb-core',
    'oxmysql',
    'ox_lib',
    'hc-core',
}
