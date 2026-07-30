-- =========================================================
--  BRIDGE DE INVENTÁRIO
--  Detecta automaticamente se o servidor usa ox_inventory ou
--  qb-inventory (padrão do qb-core/qbx_core) e expõe sempre
--  as mesmas funções: GetItemCount, RemoveItem, AddItem.
-- =========================================================

Inventory = {}

local function ResolveInventory()
    if Config.Inventory == 'ox_inventory' then return 'ox_inventory' end
    if Config.Inventory == 'qb-inventory' then return 'qb-inventory' end

    -- auto: usa ox_inventory se estiver rodando, senão cai pro padrão qb-inventory
    if GetResourceState('ox_inventory') == 'started' or GetResourceState('ox_inventory') == 'starting' then
        return 'ox_inventory'
    end

    return 'qb-inventory'
end

local InventorySystem = ResolveInventory()

-- Quantidade que o jogador (source) possui de um item
function Inventory.GetItemCount(source, item)
    if InventorySystem == 'ox_inventory' then
        local ok, count = pcall(function()
            return exports.ox_inventory:GetItemCount(source, item)
        end)
        return ok and count or 0
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return 0 end

    local itemData = Player.Functions.GetItemByName(item)
    return itemData and (itemData.amount or itemData.count or 0) or 0
end

-- Remove "count" unidades do item do jogador. Retorna true/false.
function Inventory.RemoveItem(source, item, count)
    if InventorySystem == 'ox_inventory' then
        local ok, result = pcall(function()
            return exports.ox_inventory:RemoveItem(source, item, count)
        end)
        return ok and result
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    return Player.Functions.RemoveItem(item, count)
end

-- Adiciona "count" unidades do item ao jogador. Retorna true/false.
function Inventory.AddItem(source, item, count)
    if InventorySystem == 'ox_inventory' then
        local ok, result = pcall(function()
            return exports.ox_inventory:AddItem(source, item, count)
        end)
        return ok and result
    end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    return Player.Functions.AddItem(item, count)
end
