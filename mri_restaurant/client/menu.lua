local menuOpen = false

function IsMenuOpen()
    return menuOpen
end

-- =========================================================
--  VERIFICAÇÕES LOCAIS (client-side, só para exibir/ocultar abas -
--  toda ação real é revalidada no servidor)
-- =========================================================
function IsPlayerEmployee(restaurantIndex)
    local playerData = QBCore.Functions.GetPlayerData()
    local playerJob = playerData.job.name
    local restaurant = Config.Restaurants[restaurantIndex]
    if not restaurant then return false end

    for _, job in pairs(restaurant.allowedJobs) do
        if playerJob == job then return true end
    end
    return false
end

function IsPlayerManager(restaurantIndex)
    local playerData = QBCore.Functions.GetPlayerData()
    local restaurant = Config.Restaurants[restaurantIndex]
    if not restaurant then return false end
    if not IsPlayerEmployee(restaurantIndex) then return false end

    local playerGrade = playerData.job.grade.level
    for _, grade in pairs(restaurant.managerGrades or {}) do
        if playerGrade == grade then return true end
    end
    return false
end

function GetPlayerRestaurantIndex()
    local playerData = QBCore.Functions.GetPlayerData()
    local playerJob = playerData.job.name

    for i, restaurant in pairs(Config.Restaurants) do
        for _, job in pairs(restaurant.allowedJobs) do
            if playerJob == job then return i end
        end
    end
    return nil
end

-- =========================================================
--  ABRIR TABLET
-- =========================================================
function OpenRestaurantMenu()
    if menuOpen then return end

    local playerData = QBCore.Functions.GetPlayerData()
    local playerJob = playerData.job.name
    local playerGrade = playerData.job.grade.level
    local employeeRestaurantIndex = GetPlayerRestaurantIndex()
    local onDuty = playerData.job.onduty ~= false

    HandleTabletAnimation(true)

    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetAllRestaurants', function(restaurants)
        Config.Restaurants = restaurants

        local restaurantsData = {}
        for i, restaurant in pairs(restaurants) do
            restaurantsData[#restaurantsData + 1] = {
                id = i,
                name = restaurant.name,
                label = restaurant.label,
                logo = restaurant.logo,
                banner = restaurant.banner,
                status = restaurant.isOpen,
                isEmployee = IsPlayerEmployee(i),
                isManager = IsPlayerManager(i),
            }
        end

        table.sort(restaurantsData, function(a, b) return a.id < b.id end)

        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = "openMenu",
            restaurants = restaurantsData,
            job = playerJob,
            grade = playerGrade,
            onDuty = onDuty,
            employeeRestaurantIndex = employeeRestaurantIndex,
            playerServerId = GetPlayerServerId(PlayerId()),
            enablePickupOrders = Config.EnableTabletPickupOrders ~= false,
        })

        menuOpen = true
    end)
end

-- =========================================================
--  TOTEM DE AUTOATENDIMENTO
--  Aberto pelos props espalhados pelo mapa (spawn/interação em
--  client.lua), não pelo tablet/comando normal. Qualquer cliente pode
--  usar - não exige ser funcionário. Mostra só o cardápio + carrinho
--  daquele restaurante específico, sem as abas de funcionário/gerência.
-- =========================================================
function OpenTotemOrderMenu(restaurantIndex)
    if menuOpen then return end

    local restaurant = Config.Restaurants[restaurantIndex]
    if not restaurant then return end

    -- O próprio callback já decide se o totem pode ser usado (sem nenhum
    -- funcionário de plantão) e devolve o cardápio com o "aberto" certo
    -- pro modo autoatendimento. Com funcionário de plantão, vem nil.
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetTotemMenu', function(menuData)
        if not menuData then
            QBCore.Functions.Notify(Lang:t('error.totem_staff_online'), 'error')
            return
        end

        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(false)
        SendNUIMessage({
            action = "openTotemMenu",
            restaurant = {
                id = restaurantIndex,
                name = menuData.name,
                label = menuData.label,
                logo = restaurant.logo,
                banner = restaurant.banner,
                isOpen = menuData.isOpen,
                menu = menuData.menu,
            },
            playerServerId = GetPlayerServerId(PlayerId()),
        })

        menuOpen = true
    end, restaurantIndex)
end

RegisterCommand('restaurantmenu', function()
    OpenRestaurantMenu()
end, false)

RegisterKeyMapping('restaurantmenu', 'Abrir Gerenciamento de Restaurante', 'keyboard', Config.RestaurantMenuKey)

RegisterNetEvent('rm-restaurant:client:OpenMenu', function()
    OpenRestaurantMenu()
end)

RegisterNUICallback('closeMenu', function(data, cb)
    if data and data.missionActive then
        -- Missão de preparo ainda ativa: mantém o cursor liberado pro
        -- funcionário clicar no painel flutuante, mas sem travar os
        -- controles do personagem (SetNuiFocusKeepInput).
        SetNuiFocus(true, false)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    HandleTabletAnimation(false)
    menuOpen = false
    cb('ok')
end)

-- Chamado pela NUI quando a missão de preparo é encerrada (concluída ou
-- fechada) enquanto o tablet já estava fechado, pra devolver o controle
-- normal do jogo ao jogador.
RegisterNUICallback('missionClosed', function(_, cb)
    if not menuOpen then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
    cb('ok')
end)

-- =========================================================
--  CARDÁPIO / PEDIDOS (CLIENTE)
-- =========================================================
RegisterNUICallback('getMenu', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetMenu', function(menuData)
        cb(menuData)
    end, data.id)
end)

-- Usado só pela tela do totem, pra recarregar o cardápio depois de um pedido
-- sem perder o "aberto" forçado do modo autoatendimento (getMenu normal
-- devolveria o isOpen manual, que fica sempre false sem funcionário).
RegisterNUICallback('getTotemMenu', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetTotemMenu', function(menuData)
        cb(menuData)
    end, data.id)
end)

-- Usado pelo modal de "Retirada ou Entrega" para saber se há funcionários
-- suficientes de plantão antes de liberar o botão de Entrega
RegisterNUICallback('canDeliver', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:CanDeliver', function(canDeliver)
        cb({ canDeliver = canDeliver })
    end, data.id)
end)

RegisterNUICallback('placeOrder', function(data, cb)
    local deliveryCoords = nil

    -- Se o cliente escolheu entrega, captura a posição atual dele: é pra lá
    -- que o GPS do funcionário vai apontar quando o pedido ficar pronto.
    if data.orderType == 'delivery' then
        local pos = GetEntityCoords(PlayerPedId())
        deliveryCoords = { x = pos.x, y = pos.y, z = pos.z }
    end

    TriggerServerEvent('rm-restaurant:server:PlaceOrder', data.id, data.cart, data.orderType, deliveryCoords, data.couponCode, data.orderSource)
    cb('ok')
end)

-- Aba "Histórico de Pedidos": devolve os últimos pedidos do próprio jogador,
-- usado tanto pra listar quanto pra montar o carrinho de novo ao "repetir".
RegisterNUICallback('getOrderHistory', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetOrderHistory', function(history)
        cb(history)
    end)
end)

-- Aba "Atendimento": funcionário seleciona o jogador mais próximo pra ser o
-- cliente do pedido (a cobrança automática vai em cima dele lá no servidor).
RegisterNUICallback('selectCounterCustomer', function(data, cb)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local maxDistance = Config.CounterCustomerMaxDistance or 5.0

    local closestId, closestDist = nil, maxDistance
    for _, otherPlayer in ipairs(GetActivePlayers()) do
        if otherPlayer ~= PlayerId() then
            local otherPed = GetPlayerPed(otherPlayer)
            local dist = #(playerCoords - GetEntityCoords(otherPed))
            if dist < closestDist then
                closestDist = dist
                closestId = otherPlayer
            end
        end
    end

    if not closestId then
        cb({ ok = false })
        return
    end

    cb({
        ok = true,
        serverId = GetPlayerServerId(closestId),
        name = GetPlayerName(closestId),
    })
end)

-- Aba "Atendimento": funcionário monta o pedido de um cliente presencial
-- direto no balcão (sem tablet/totem do lado do cliente) e registra. O
-- dinheiro é cobrado automaticamente do cliente selecionado (customerId).
RegisterNUICallback('placeCounterOrder', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:PlaceCounterOrder', data.id, data.cart, data.customerId, data.couponCode)
    cb('ok')
end)

-- Permite o funcionário re-tracejar a rota de entrega manualmente (ex: se
-- perdeu o GPS original), usando as coordenadas que já vieram nos dados do pedido.
RegisterNUICallback('setDeliveryRouteWaypoint', function(data, cb)
    if data and data.coords then
        SetNewWaypoint(data.coords.x, data.coords.y)
        QBCore.Functions.Notify('GPS atualizado com o destino da entrega', 'primary')
    end
    cb('ok')
end)

-- =========================================================
--  COZINHA (FUNCIONÁRIOS)
-- =========================================================
RegisterNUICallback('getKitchenOrders', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetKitchenOrders', function(orders)
        cb(orders)
    end, data.id)
end)

-- Estado atual de pausa de entregas (mostrado no toggle da Cozinha)
RegisterNUICallback('getDeliveryStatus', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetDeliveryStatus', function(paused)
        cb({ paused = paused })
    end, data.id)
end)

-- Funcionário pausa/retoma entregas pelo toggle da Cozinha
RegisterNUICallback('toggleDelivery', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:ToggleDelivery', data.id, data.paused)
    cb('ok')
end)

-- Atualização em tempo real: qualquer funcionário do restaurante que estiver
-- com o tablet aberto na Cozinha vê o toggle mudar sozinho quando outro
-- colega pausar/retomar as entregas.
RegisterNetEvent('rm-restaurant:client:DeliveryStatusChanged', function(restaurantIndex, paused)
    SendNUIMessage({
        action = 'deliveryStatusChanged',
        id = restaurantIndex,
        paused = paused,
    })
end)

RegisterNUICallback('getRecipeItemCounts', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetRecipeItemCounts', function(counts)
        cb(counts)
    end, data.items)
end)

RegisterNUICallback('acceptOrder', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:AcceptOrder', data.orderId)
    cb('ok')
end)

RegisterNUICallback('markOrderReady', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:MarkOrderReady', data.orderId)
    cb('ok')
end)

RegisterNUICallback('completeOrder', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:CompleteOrder', data.orderId)
    cb('ok')
end)

RegisterNUICallback('cancelOrder', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:CancelOrder', data.orderId)
    cb('ok')
end)

-- =========================================================
--  GERÊNCIA (DONO / GERENTE)
-- =========================================================
RegisterNUICallback('accessManagement', function(data, cb)
    local restaurantId = data.id
    if not restaurantId then cb('error') return end

    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetManagementData', function(managementData)
        if managementData then
            cb(managementData)
        else
            QBCore.Functions.Notify('Você não tem permissões de gerente para este restaurante', 'error')
            cb('unauthorized')
        end
    end, restaurantId)
end)

RegisterNUICallback('updateMenuItem', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:UpdateMenuItem', data.id, data.itemId, data.changes)
    cb('ok')
end)

RegisterNUICallback('withdrawTill', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:WithdrawTill', data.id, data.amount)
    cb('ok')
end)

RegisterNUICallback('getSalesLog', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetSalesLog', function(sales)
        cb(sales)
    end, data.id)
end)

RegisterNUICallback('getItemsSoldStats', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetItemsSoldStats', function(stats)
        cb(stats)
    end, data.id)
end)

RegisterNUICallback('createMenuItem', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:CreateMenuItem', data.id, data.item)
    cb('ok')
end)

RegisterNUICallback('getManageStockLog', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetStockLog', function(log)
        cb(log)
    end, data.id)
end)

-- =========================================================
--  CUPONS DE DESCONTO (GERÊNCIA)
-- =========================================================
RegisterNUICallback('getCoupons', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetCoupons', function(coupons)
        cb(coupons)
    end, data.id)
end)

RegisterNUICallback('createCoupon', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:CreateCoupon', data.id, data.coupon)
    cb('ok')
end)

RegisterNUICallback('toggleCoupon', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:ToggleCoupon', data.id, data.couponId, data.active)
    cb('ok')
end)

RegisterNUICallback('deleteCoupon', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:DeleteCoupon', data.id, data.couponId)
    cb('ok')
end)

-- Usado pelo cliente no carrinho, pra validar o cupom antes de finalizar o pedido
RegisterNUICallback('validateCoupon', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:ValidateCoupon', function(result)
        cb(result)
    end, data.id, data.code)
end)

-- =========================================================
--  ESTOQUE (QUALQUER FUNCIONÁRIO)
-- =========================================================
RegisterNUICallback('getStockData', function(data, cb)
    QBCore.Functions.TriggerCallback('rm-restaurant:server:GetStockData', function(stockData)
        cb(stockData)
    end, data.id)
end)

RegisterNUICallback('addStock', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:AddStock', data.id, data.itemId, data.qty)
    cb('ok')
end)

RegisterNUICallback('removeStock', function(data, cb)
    TriggerServerEvent('rm-restaurant:server:RemoveStock', data.id, data.itemId, data.qty)
    cb('ok')
end)

-- =========================================================
--  ALTERNAR ABERTO/FECHADO E OUTROS CALLBACKS JÁ EXISTENTES
-- =========================================================
RegisterNUICallback('toggleRestaurant', function(data, cb)
    local restaurantId = data.id
    local state = data.state

    if not restaurantId then cb('error') return end

    QBCore.Functions.TriggerCallback('rm-restaurant:server:HasPermission', function(hasPermission)
        if hasPermission then
            ToggleRestaurant(restaurantId, state)
            cb('ok')
        else
            QBCore.Functions.Notify('Você não está autorizado a alterar o status do restaurante', 'error')
            cb('unauthorized')
        end
    end, restaurantId)
end)

RegisterNUICallback('notifyClient', function(data, cb)
    if data.message and data.type then
        QBCore.Functions.Notify(data.message, data.type)
    end
    cb('ok')
end)

exports('OpenRestaurantMenu', OpenRestaurantMenu)
