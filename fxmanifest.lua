fx_version 'cerulean'
game 'gta5'

description 'forge-radialmenu'
repository 'https://github.com/Qbox-project/forge-radialmenu'
version '0.1.2'
dependency 'pr_bridge'


shared_scripts {
    '@pr_bridge/init.lua',
    'shared/locale.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/*.lua',
}

server_scripts {
    'server/*.lua',
}

files {
    'config/client.lua',
    'locales/*.json',
}

lua54 'yes'
use_experimental_fxv2_oal 'yes'
