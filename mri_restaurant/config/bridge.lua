-- =========================================================
--  BRIDGE DE FRAMEWORK
--  Detecta automaticamente se o servidor roda qbx_core (Qbox)
--  ou qb-core (QBCore) e expõe sempre o mesmo objeto "QBCore".
-- =========================================================

local function ResolveCore()
    if Config.Framework == 'qbx_core' then
        return exports['qbx_core']:GetCoreObject()
    elseif Config.Framework == 'qb-core' then
        return exports['qb-core']:GetCoreObject()
    end

    -- auto: tenta qbx_core primeiro (Qbox), depois qb-core
    local ok, core = pcall(function()
        return exports['qbx_core']:GetCoreObject()
    end)
    if ok and core then return core end

    ok, core = pcall(function()
        return exports['qb-core']:GetCoreObject()
    end)
    if ok and core then return core end

    error('[rm-restaurant] Não foi possível encontrar qbx_core nem qb-core. Ajuste Config.Framework em config.lua')
end

QBCore = ResolveCore()
