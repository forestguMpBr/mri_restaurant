fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'love_restaurant'
description 'Restaurant management & ordering system for LoveCity (QBox/QBCore)'
author 'Dentista'
version '2.1.0'

-- Créditos: Dentista (desenvolvimento), Claude - Anthropic (assistência de IA), rafa4l (colaboração)

shared_scripts {
    'config/config.lua',
    'config/bridge.lua',
    'locales/locales.lua',
}

client_scripts {
    'client/main.lua',
    'client/menu.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/inventory.lua',
    'server/main.lua',
}

dependencies {
    'qbx_core', -- ou 'qb-core', ajuste Config.Framework em config/config.lua se necessário
    'oxmysql',  -- usado para persistir cardápio, estoque, caixa, vendas e registro de estoque no banco
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/app.js',
    'html/style.css',
    'html/img/*.png',
    'html/img/*.jpg',
    'html/img/items/*.png',
}
