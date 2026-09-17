fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'hc-clothing'
author 'Heartless City RP'
description 'Fashion / clothing shop hooks for updated packs'
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
    'hc-core',
}
