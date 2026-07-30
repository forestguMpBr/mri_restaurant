local PlayerData = {}
local tabletObj = nil
local restaurantBlips = {}

-- =========================================================
--  DADOS DO JOGADOR
-- =========================================================
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    PlayerData = QBCore.Functions.GetPlayerData()
    TriggerServerEvent('rm-restaurant:server:GetRestaurantsStatus')
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    PlayerData.job = JobInfo
end)

-- =========================================================
--  COBRANÇA DE BALCÃO (CLIENTE) - aceitar ou recusar
--  Quando um funcionário registra um pedido de balcão pra este jogador
--  na aba "Atendimento", o servidor NÃO cobra na hora: manda uma
--  solicitação de cobrança e este jogador tem alguns segundos pra
--  aceitar (E) ou recusar (BACKSPACE). Sem NUI/foco de mouse, pra não
--  atrapalhar quem está só parado no balcão.
-- =========================================================
local activeChargeRequest = nil

local function DrawChargePromptFrame(restaurantLabel, amount)
    local title = Lang:t('info.charge_prompt', { restaurant = restaurantLabel, amount = amount })
    local hint = Lang:t('info.charge_prompt_hint')

    DrawRect(0.5, 0.90, 0.44, 0.095, 0, 0, 0, 170)

    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.36, 0.36)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(title)
    DrawText(0.5, 0.868)

    SetTextFont(4)
    SetTextProportional(1)
    SetTextScale(0.32, 0.32)
    SetTextColour(80, 255, 140, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(hint)
    DrawText(0.5, 0.910)
end

RegisterNetEvent('rm-restaurant:client:CounterChargeRequest', function(data)
    activeChargeRequest = data
    local requestId = data.requestId
    local expireAt = GetGameTimer() + 30000

    PlaySoundFrontend(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", true)

    CreateThread(function()
        while activeChargeRequest and activeChargeRequest.requestId == requestId do
            if GetGameTimer() >= expireAt then
                activeChargeRequest = nil
                break
            end

            DisableControlAction(0, 38, true)  -- E
            DisableControlAction(0, 202, true) -- Backspace

            DrawChargePromptFrame(data.restaurant, data.total)

            if IsDisabledControlJustReleased(0, 38) then -- E = aceitar
                TriggerServerEvent('rm-restaurant:server:CounterChargeResponse', requestId, true)
                activeChargeRequest = nil
                break
            elseif IsDisabledControlJustReleased(0, 202) then -- Backspace = recusar
                TriggerServerEvent('rm-restaurant:server:CounterChargeResponse', requestId, false)
                activeChargeRequest = nil
                break
            end

            Wait(0)
        end
    end)
end)

-- O servidor cancelou a solicitação por timeout (cliente não respondeu a tempo)
RegisterNetEvent('rm-restaurant:client:CounterChargeExpired', function(requestId)
    if activeChargeRequest and activeChargeRequest.requestId == requestId then
        activeChargeRequest = nil
        QBCore.Functions.Notify(Lang:t('info.customer_charge_timeout'), 'error', Config.NotificationDuration)
    end
end)

-- =========================================================
--  SINCRONIZAÇÃO DE RESTAURANTES
-- =========================================================
RegisterNetEvent('rm-restaurant:client:SyncRestaurants', function(restaurants)
    Config.Restaurants = restaurants
    UpdateRestaurantBlips()
end)

RegisterNetEvent('rm-restaurant:client:RestaurantStateChanged', function(restaurantIndex, isOpen)
    if Config.Restaurants[restaurantIndex] then
        Config.Restaurants[restaurantIndex].isOpen = isOpen
    end
    UpdateRestaurantBlips()

    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'restaurantStateChanged', restaurantIndex = restaurantIndex, isOpen = isOpen })
    end
end)

-- =========================================================
--  PEDIDOS: EVENTOS EM TEMPO REAL
-- =========================================================
RegisterNetEvent('rm-restaurant:client:NewOrder', function(order, restaurantLabel)
    PlaySoundFrontend(-1, "Text_Arrive_Tone", "Phone_SoundSet_Default", true)

    local msgKey = 'info.new_order'
    if order.orderSource == 'totem' then
        msgKey = 'info.new_order_totem'
    elseif order.orderSource == 'counter' then
        msgKey = 'info.new_order_counter'
    end
    QBCore.Functions.Notify(Lang:t(msgKey, { restaurant = restaurantLabel }), 'primary', Config.NotificationDuration)

    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'newOrder', order = order })
    end
end)

RegisterNetEvent('rm-restaurant:client:OrderUpdated', function(order)
    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'orderUpdated', order = order })
    end

    -- Pedido acabou de ser aceito (pending -> preparing): mostra a "missão de
    -- preparo" para TODOS os funcionários de plantão do restaurante, não só
    -- quem aceitou. Só quem aceitou, porém, pode marcar como pronto (isAssigned).
    if order.status == 'preparing' and IsPlayerEmployee and IsPlayerEmployee(order.restaurantIndex) then
        local isAssigned = order.employeeId == GetPlayerServerId(PlayerId())
        SendNUIMessage({ action = 'showPrepMission', order = order, isAssigned = isAssigned })
    end
end)

RegisterNetEvent('rm-restaurant:client:OrderReady', function(order)
    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'orderReady', order = order })
    end
end)

RegisterNetEvent('rm-restaurant:client:MenuUpdated', function(restaurantIndex, menu)
    if Config.Restaurants[restaurantIndex] then
        Config.Restaurants[restaurantIndex].menu = menu
    end
    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'menuUpdated', restaurantIndex = restaurantIndex, menu = menu })
    end
end)

RegisterNetEvent('rm-restaurant:client:BalanceUpdated', function(restaurantIndex, balance)
    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'balanceUpdated', restaurantIndex = restaurantIndex, balance = balance })
    end
end)

RegisterNetEvent('rm-restaurant:client:StockLogUpdated', function(restaurantIndex)
    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'stockLogUpdated', restaurantIndex = restaurantIndex })
    end
end)

-- =========================================================
--  ENTREGA: GPS automático quando o funcionário termina o preparo
-- =========================================================
RegisterNetEvent('rm-restaurant:client:SetDeliveryWaypoint', function(coords, orderId)
    if not coords then return end
    SetNewWaypoint(coords.x, coords.y)
    QBCore.Functions.Notify(Lang:t('info.delivery_waypoint_set', { id = orderId }), 'primary', Config.NotificationDuration)
end)

-- =========================================================
--  CUPONS: avisa a NUI (aba Gerenciar) quando a lista muda
-- =========================================================
RegisterNetEvent('rm-restaurant:client:CouponsUpdated', function(restaurantIndex, coupons)
    if IsMenuOpen and IsMenuOpen() then
        SendNUIMessage({ action = 'couponsUpdated', restaurantIndex = restaurantIndex, coupons = coupons })
    end
end)

RegisterNetEvent('rm-restaurant:client:ShowRestaurantNotification', function(data)
    SendNUIMessage({ action = 'showRestaurantNotification', restaurantId = data.restaurantId,
        restaurantName = data.restaurantName, restaurantImage = data.restaurantImage,
        isOpen = data.isOpen, statusText = data.statusText, message = data.message })
end)

-- =========================================================
--  BLIPS
-- =========================================================
function CreateRestaurantBlip(restaurant)
    local blip = AddBlipForCoord(restaurant.location.x, restaurant.location.y, restaurant.location.z)
    SetBlipSprite(blip, restaurant.blip.sprite or 106)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, restaurant.blip.scale or 0.7)
    SetBlipColour(blip, restaurant.isOpen and 2 or 1)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")

    local displayName = restaurant.label or restaurant.name or "Restaurante"
    local statusText = restaurant.isOpen and " [ABERTO]" or " [FECHADO]"
    AddTextComponentString(displayName .. statusText)
    EndTextCommandSetBlipName(blip)

    return blip
end

function UpdateRestaurantBlips()
    for _, blip in pairs(restaurantBlips) do
        RemoveBlip(blip)
    end
    restaurantBlips = {}

    for i, restaurant in pairs(Config.Restaurants) do
        restaurantBlips[i] = CreateRestaurantBlip(restaurant)
    end
end

CreateThread(function()
    TriggerServerEvent('rm-restaurant:server:GetRestaurantsStatus')
    Wait(1000)
    UpdateRestaurantBlips()
end)

-- =========================================================
--  ANIMAÇÃO DO TABLET
-- =========================================================
function HandleTabletAnimation(state)
    local playerPed = PlayerPedId()
    local animDict = Config.TabletAnimDict
    local animName = Config.TabletAnim

    if state then
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(100) end

        local tabletModel = GetHashKey(Config.TabletModel)
        RequestModel(tabletModel)
        while not HasModelLoaded(tabletModel) do Wait(100) end

        tabletObj = CreateObject(tabletModel, 0.0, 0.0, 0.0, true, true, false)
        local tabletBoneIndex = GetPedBoneIndex(playerPed, Config.TabletBone)

        AttachEntityToEntity(tabletObj, playerPed, tabletBoneIndex,
            Config.TabletOffset.x, Config.TabletOffset.y, Config.TabletOffset.z,
            Config.TabletRot.x, Config.TabletRot.y, Config.TabletRot.z,
            true, false, false, false, 2, true)

        SetModelAsNoLongerNeeded(tabletModel)

        CreateThread(function()
            -- A animação já roda em loop (-1) sozinha; só precisamos checar
            -- periodicamente se ela foi interrompida (ex: ragdoll, combate) e
            -- retomar. Checar isso a cada frame (Wait(0)) gastava natives
            -- (DoesEntityExist/IsEntityPlayingAnim) 60x/s à toa - a cada 500ms
            -- já garante a mesma responsividade percebida com uma fração do custo.
            while DoesEntityExist(tabletObj) do
                if not IsEntityPlayingAnim(playerPed, animDict, animName, 3) then
                    TaskPlayAnim(playerPed, animDict, animName, 3.0, 3.0, -1, 49, 0, 0, 0, 0)
                end
                Wait(500)
            end
        end)
    else
        if DoesEntityExist(tabletObj) then
            StopAnimTask(playerPed, animDict, animName, 1.0)
            DeleteEntity(tabletObj)
            tabletObj = nil
        end
    end
end

-- =========================================================
--  AÇÕES DE RESTAURANTE
-- =========================================================
function ToggleRestaurant(restaurantIndex, state)
    TriggerServerEvent('rm-restaurant:server:ToggleRestaurant', restaurantIndex, state)
end

RegisterNUICallback('setWaypoint', function(data, cb)
    local id = data.id
    local name = data.name or "Restaurante"

    if id and Config.Restaurants[id] then
        local restaurant = Config.Restaurants[id]
        local location = restaurant.location
        SetNewWaypoint(location.x, location.y)
        QBCore.Functions.Notify(Lang:t('success.waypoint_set', { restaurant = name }), "success")
        cb('ok')
    else
        QBCore.Functions.Notify("Não foi possível definir GPS - Restaurante não encontrado", "error")
        cb('error')
    end
end)

RegisterNUICallback('notifyAllPlayers', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:NotifyAllPlayers', data)
    cb('ok')
end)

function SetRestaurantWaypoint(restaurantName)
    for i, restaurant in pairs(Config.Restaurants) do
        if restaurant.name == restaurantName or restaurant.label == restaurantName then
            SetNewWaypoint(restaurant.location.x, restaurant.location.y)
            QBCore.Functions.Notify(Lang:t('success.waypoint_set', { restaurant = restaurant.label }), "success")
            return true
        end
    end
    QBCore.Functions.Notify("Restaurante não encontrado", "error")
    return false
end

RegisterCommand('restaurantgps', function(_, args)
    if #args == 0 then
        QBCore.Functions.Notify("Por favor, especifique um nome de restaurante", "error")
        return
    end
    SetRestaurantWaypoint(table.concat(args, " "))
end, false)

exports('SetRestaurantWaypoint', SetRestaurantWaypoint)
exports('ToggleRestaurant', ToggleRestaurant)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and tabletObj and DoesEntityExist(tabletObj) then
        DeleteEntity(tabletObj)
    end
end)

-- =========================================================
--  TOTENS DE AUTOATENDIMENTO (pedido pelo totem, sem funcionário)
--  Spawna os props configurados em Config.Restaurants[i].totems e
--  registra a interação (ox_target > qb-target/qtarget > fallback
--  nativo com tecla E), abrindo OpenTotemOrderMenu (menu.lua) quando
--  o cliente escolhe "Fazer Pedido".
-- =========================================================
local totemObjects = {}

local function ResolveTotemTargetSystem()
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
    if GetResourceState('qtarget') == 'started' then return 'qb-target' end
    return 'native'
end

local TotemTargetSystem = ResolveTotemTargetSystem()

local function DrawTotemText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end

local totemZoneNames = {} -- nomes/ids das zonas (ox_target/qb-target) criadas, pra remover no stop

local function RegisterTotemInteraction(entity, restaurantIndex, restaurantLabel)
    local label = ('%s: %s'):format(restaurantLabel or 'Restaurante', Config.TotemTargetLabel or 'Fazer Pedido')

    if TotemTargetSystem == 'ox_target' then
        exports.ox_target:addLocalEntity(entity, {
            {
                icon = Config.TotemTargetIcon or 'fas fa-concierge-bell',
                label = label,
                distance = Config.TotemInteractDistance or 1.5,
                onSelect = function() OpenTotemOrderMenu(restaurantIndex) end,
            }
        })
    elseif TotemTargetSystem == 'qb-target' then
        exports['qb-target']:AddTargetEntity(entity, {
            options = {
                {
                    icon = Config.TotemTargetIcon or 'fas fa-concierge-bell',
                    label = label,
                    action = function() OpenTotemOrderMenu(restaurantIndex) end,
                }
            },
            distance = Config.TotemInteractDistance or 1.5,
        })
    else
        -- Fallback nativo: sem ox_target/qb-target instalado, mostra um
        -- texto 3D e espera o jogador apertar E (control 38) perto do totem.
        CreateThread(function()
            while DoesEntityExist(entity) do
                local sleep = 1000
                local playerCoords = GetEntityCoords(PlayerPedId())
                local entityCoords = GetEntityCoords(entity)
                local dist = #(playerCoords - entityCoords)

                if dist < (Config.TotemInteractDistance or 1.5) + 1.0 then
                    sleep = 0
                    DrawTotemText3D(entityCoords.x, entityCoords.y, entityCoords.z + 0.65, ('[E] %s'):format(label))
                    if IsControlJustReleased(0, 38) then
                        OpenTotemOrderMenu(restaurantIndex)
                    end
                end

                Wait(sleep)
            end
        end)
    end
end

-- =========================================================
--  TOTEM POR COORDENADA (sem prop spawnado)
--  Usado quando `useProp = false` no totem: cria só a zona/target na
--  coordenada informada, sem CreateObject nenhum. Útil quando o totem já
--  existe fisicamente no mapa (YMAP, MLO, prop de outro resource) e você
--  só quer a interação naquele ponto específico.
-- =========================================================
local function RegisterTotemZoneInteraction(coords, restaurantIndex, restaurantLabel)
    local label = ('%s: %s'):format(restaurantLabel or 'Restaurante', Config.TotemTargetLabel or 'Fazer Pedido')
    local zoneName = ('rm_totem_zone_%s_%s'):format(restaurantIndex, #totemZoneNames + 1)
    local dist = Config.TotemInteractDistance or 1.5

    if TotemTargetSystem == 'ox_target' then
        -- addBoxZone retorna o id numérico da zona - é ESSE id que precisa
        -- ser guardado pra remoção (removeZone), não um nome inventado.
        local zoneId = exports.ox_target:addBoxZone({
            coords = vector3(coords.x, coords.y, coords.z),
            size = vector3(dist * 2, dist * 2, 2.0),
            rotation = coords.w or 0.0,
            debug = false,
            options = {
                {
                    icon = Config.TotemTargetIcon or 'fas fa-concierge-bell',
                    label = label,
                    onSelect = function() OpenTotemOrderMenu(restaurantIndex) end,
                }
            },
        })
        totemZoneNames[#totemZoneNames + 1] = { system = 'ox_target', id = zoneId }

    elseif TotemTargetSystem == 'qb-target' then
        exports['qb-target']:AddBoxZone(zoneName, vector3(coords.x, coords.y, coords.z), dist * 2, dist * 2, {
            name = zoneName,
            heading = coords.w or 0.0,
            debug = false,
            minZ = coords.z - 1.0,
            maxZ = coords.z + 1.0,
        }, {
            options = {
                {
                    icon = Config.TotemTargetIcon or 'fas fa-concierge-bell',
                    label = label,
                    action = function() OpenTotemOrderMenu(restaurantIndex) end,
                }
            },
            distance = dist,
        })
        totemZoneNames[#totemZoneNames + 1] = { system = 'qb-target', id = zoneName }

    else
        -- Fallback nativo: mesma lógica do totem com prop, mas comparando a
        -- distância direto contra a coordenada configurada (não existe entidade).
        CreateThread(function()
            while true do
                local sleep = 1000
                local playerCoords = GetEntityCoords(PlayerPedId())
                local zoneCoords = vector3(coords.x, coords.y, coords.z)
                local d = #(playerCoords - zoneCoords)

                if d < dist + 1.0 then
                    sleep = 0
                    DrawTotemText3D(zoneCoords.x, zoneCoords.y, zoneCoords.z + 0.65, ('[E] %s'):format(label))
                    if IsControlJustReleased(0, 38) then
                        OpenTotemOrderMenu(restaurantIndex)
                    end
                end

                Wait(sleep)
            end
        end)
    end
end

-- Normaliza cada entrada de `restaurant.totems`, aceitando tanto o formato
-- antigo (vector4 puro, sempre spawna prop) quanto o novo formato em tabela:
--   { coords = vector4(x, y, z, heading), useProp = false }
-- useProp default é true, então configs existentes continuam funcionando
-- sem nenhuma alteração.
local function NormalizeTotemEntry(entry)
    if type(entry) == 'table' and entry.coords then
        return {
            coords = entry.coords,
            useProp = entry.useProp ~= false,
            model = entry.model or Config.TotemModel,
        }
    end

    -- entry é um vector4 "cru" (comportamento antigo, sempre spawna prop)
    return {
        coords = entry,
        useProp = true,
        model = Config.TotemModel,
    }
end

local function SpawnRestaurantTotems()
    if not Config.EnableTotems then return end

    for i, restaurant in pairs(Config.Restaurants) do
        if restaurant.totems then
            for _, rawTotem in pairs(restaurant.totems) do
                local totem = NormalizeTotemEntry(rawTotem)
                local totemCoord = totem.coords

                if totem.useProp then
                    local model = GetHashKey(totem.model)
                    RequestModel(model)
                    local attempts = 0
                    while not HasModelLoaded(model) and attempts < 100 do
                        Wait(10)
                        attempts = attempts + 1
                    end

                    if HasModelLoaded(model) then
                        local obj = CreateObject(model, totemCoord.x, totemCoord.y, totemCoord.z - 1.0, false, false, false)
                        PlaceObjectOnGroundProperly(obj)
                        SetEntityHeading(obj, totemCoord.w or 0.0)
                        FreezeEntityPosition(obj, true)
                        SetEntityInvincible(obj, true)
                        SetModelAsNoLongerNeeded(model)

                        totemObjects[#totemObjects + 1] = obj
                        RegisterTotemInteraction(obj, i, restaurant.label)
                    end
                else
                    -- Sem prop: só registra a zona/target na coordenada informada.
                    RegisterTotemZoneInteraction(totemCoord, i, restaurant.label)
                end
            end
        end
    end
end

CreateThread(function()
    Wait(2000) -- dá tempo do rm-restaurant:client:SyncRestaurants popular Config.Restaurants
    SpawnRestaurantTotems()
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, obj in pairs(totemObjects) do
            if DoesEntityExist(obj) then DeleteEntity(obj) end
        end

        for _, zone in pairs(totemZoneNames) do
            if zone.system == 'ox_target' then
                exports.ox_target:removeZone(zone.id)
            elseif zone.system == 'qb-target' then
                exports['qb-target']:RemoveZone(zone.id)
            end
        end
    end
end)

-- Comando auxiliar pra posicionar os totens: fique de frente pro lugar que
-- quer colocar o totem e rode esse comando - ele imprime no chat/console as
-- coordenadas prontas pra colar no `totems = { ... }` de cada restaurante
-- em config.lua.
RegisterCommand('totempos', function()
    local coords = GetEntityCoords(PlayerPedId())
    local heading = GetEntityHeading(PlayerPedId())
    local formatted = ('vector4(%.2f, %.2f, %.2f, %.2f)'):format(coords.x, coords.y, coords.z, heading)

    TriggerEvent('chat:addMessage', {
        args = { '[rm-restaurant]', 'Coordenada do totem: ' .. formatted }
    })
    print('[rm-restaurant] Coordenada do totem: ' .. formatted)
end, false)
