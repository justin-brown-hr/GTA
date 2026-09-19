fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hc-jobs'
author 'Heartless City RP'
description 'Civilian jobs and legal money activities'
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
    'qb-vehiclekeys',
    'ox_lib',
    'ox_target',
    'hc-core',
}
