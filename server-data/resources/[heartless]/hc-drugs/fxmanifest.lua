fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hc-drugs'
author 'Heartless City RP'
description 'Custom drug gather, process, and sell loops'
version '0.1.0'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
}

client_scripts {
    'client/main.lua',
}

server_scripts {
    'server/main.lua',
}

dependencies {
    'qb-core',
    'ox_lib',
    'ox_inventory',
    'ox_target',
    'hc-core',
}
