-- =========================================================
--  ESTADO EM MEMÓRIA (cache; a fonte da verdade é o banco de dados)
-- =========================================================
local Orders = {}       -- [orderId] = order (pedidos em andamento, não precisam persistir)
local OrderIdCounter = 0

local function T(key, vars)
    if not Lang or not Lang.t then return key end
    return Lang:t(key, vars)
end

local function Notify(src, message, type)
    TriggerClientEvent('QBCore:Notify', src, message, type, Config.NotificationDuration)
end

-- =========================================================
--  PERSISTÊNCIA (oxmysql)
--  Cardápio, estoque, caixa, vendas e registro de estoque
--  agora vivem no banco de dados. O objeto Config.Restaurants
--  continua sendo usado em memória como cache de leitura rápida,
--  mas toda alteração é sempre gravada no banco também.
-- =========================================================
local function PersistMenuItem(restaurantIndex, menuItem)
    MySQL.update(
        'UPDATE rm_restaurant_menu SET price = ?, stock = ?, enabled = ? WHERE restaurant_index = ? AND item_id = ?',
        { menuItem.price, menuItem.stock, menuItem.enabled and 1 or 0, tonumber(restaurantIndex), menuItem.id }
    )
end

local function PersistBalance(restaurantIndex, balance)
    MySQL.update(
        'UPDATE rm_restaurant_data SET balance = ? WHERE restaurant_index = ?',
        { balance, tonumber(restaurantIndex) }
    )
end

local function PersistStockLogEntry(restaurantIndex, employeeName, itemName, action, qty, createdAt)
    MySQL.insert(
        'INSERT INTO rm_restaurant_stocklog (restaurant_index, employee_name, item_name, action, qty, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        { tonumber(restaurantIndex), employeeName, itemName, action, qty, createdAt }
    )
end

local function PersistSale(sale)
    MySQL.insert(
        'INSERT INTO rm_restaurant_sales (order_id, restaurant_index, employee_id, employee_name, customer_name, items, total, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        { sale.orderId, sale.restaurantIndex, sale.employeeId, sale.employeeName, sale.customerName, json.encode(sale.items), sale.total, sale.createdAt }
    )
end

local function IncrementCouponUse(couponId)
    MySQL.update('UPDATE rm_restaurant_coupons SET uses = uses + 1 WHERE id = ?', { couponId })
end

-- =========================================================
--  HISTÓRICO DE PEDIDOS (CLIENTE)
--  Salva cada pedido feito pelo cliente (tablet/totem) vinculado ao
--  citizenid dele, pra alimentar a aba "Histórico de Pedidos" no tablet
--  e permitir repetir um pedido antigo com 1 clique.
-- =========================================================
local function PersistOrderHistory(entry)
    MySQL.insert(
        'INSERT INTO rm_restaurant_order_history (citizenid, order_id, restaurant_index, items, total, discount, coupon_code, order_type, order_source, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { entry.citizenid, entry.orderId, entry.restaurantIndex, json.encode(entry.items), entry.total, entry.discount or 0, entry.couponCode, entry.orderType, entry.orderSource, entry.createdAt }
    )
end

local function RecordOrderHistory(order, citizenid)
    if not citizenid then return end
    PersistOrderHistory({
        citizenid = citizenid,
        orderId = order.id,
        restaurantIndex = order.restaurantIndex,
        items = order.items,
        total = order.total,
        discount = order.discount,
        couponCode = order.couponCode,
        orderType = order.orderType,
        orderSource = order.orderSource,
        createdAt = order.createdAt,
    })
end

-- =========================================================
--  INICIALIZAÇÃO: carrega/semeia o banco e popula Config.Restaurants
-- =========================================================
local function LoadRestaurantsFromDB()
    for i, restaurant in pairs(Config.Restaurants) do
        restaurant.isOpen = false
        restaurant.deliveryPaused = false -- controlado pelo funcionário na Cozinha, não persiste entre restarts

        -- caixa (rm_restaurant_data)
        local dataRow = MySQL.single.await('SELECT * FROM rm_restaurant_data WHERE restaurant_index = ?', { i })
        if not dataRow then
            MySQL.insert.await('INSERT INTO rm_restaurant_data (restaurant_index, balance) VALUES (?, ?)', { i, restaurant.balance or 0 })
            restaurant.balance = restaurant.balance or 0
        else
            restaurant.balance = dataRow.balance
        end

        -- cardápio (rm_restaurant_menu) - semeia com Config.Restaurants na primeira vez
        local existingCount = MySQL.scalar.await('SELECT COUNT(*) FROM rm_restaurant_menu WHERE restaurant_index = ?', { i })
        if existingCount == 0 and restaurant.menu then
            for _, item in pairs(restaurant.menu) do
                MySQL.insert.await(
                    'INSERT INTO rm_restaurant_menu (restaurant_index, item_id, category, name, description, price, item, image, enabled, stock, prep_time, recipe) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
                    { i, item.id, item.category, item.name, item.description or '', item.price, item.item, item.image or '', item.enabled and 1 or 0, item.stock, item.prepTime or 10, json.encode(item.recipe or {}) }
                )
            end
        end

        local rows = MySQL.query.await('SELECT * FROM rm_restaurant_menu WHERE restaurant_index = ? ORDER BY item_id ASC', { i })
        local menu = {}
        for _, row in ipairs(rows or {}) do
            local ok, decodedRecipe = pcall(json.decode, row.recipe or '[]')
            menu[#menu + 1] = {
                id = row.item_id,
                category = row.category,
                name = row.name,
                description = row.description,
                price = row.price,
                item = row.item,
                image = row.image,
                enabled = row.enabled == 1,
                stock = row.stock,
                prepTime = row.prep_time,
                recipe = (ok and decodedRecipe) or {},
            }
        end
        restaurant.menu = menu

        -- cupons de desconto (rm_restaurant_coupons)
        local couponRows = MySQL.query.await('SELECT * FROM rm_restaurant_coupons WHERE restaurant_index = ? ORDER BY created_at DESC', { i })
        local coupons = {}
        for _, row in ipairs(couponRows or {}) do
            coupons[#coupons + 1] = {
                id = row.id,
                code = row.code,
                type = row.type,
                value = row.value,
                maxUses = row.max_uses,
                uses = row.uses,
                expiresAt = row.expires_at,
                active = row.active == 1,
            }
        end
        restaurant.coupons = coupons
    end

    print('[love_restaurant] Cardápio, estoque, caixa e cupons carregados do banco de dados.')
end

CreateThread(function()
    while GetResourceState('oxmysql') ~= 'started' do
        Wait(100)
    end

    -- Garante a tabela de cupons de desconto (idempotente, roda toda subida do resource)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS rm_restaurant_coupons (
            id INT AUTO_INCREMENT PRIMARY KEY,
            restaurant_index INT NOT NULL,
            code VARCHAR(32) NOT NULL,
            type VARCHAR(10) NOT NULL DEFAULT 'percent',
            value INT NOT NULL DEFAULT 0,
            max_uses INT NOT NULL DEFAULT 0,
            uses INT NOT NULL DEFAULT 0,
            expires_at INT NOT NULL DEFAULT 0,
            active TINYINT(1) NOT NULL DEFAULT 1,
            created_at INT NOT NULL DEFAULT 0
        )
    ]])

    -- Garante a tabela de histórico de pedidos do cliente (idempotente, roda toda subida do resource)
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS rm_restaurant_order_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            citizenid VARCHAR(50) NOT NULL,
            order_id INT NOT NULL,
            restaurant_index INT NOT NULL,
            items LONGTEXT NOT NULL,
            total INT NOT NULL DEFAULT 0,
            discount INT NOT NULL DEFAULT 0,
            coupon_code VARCHAR(32) DEFAULT NULL,
            order_type VARCHAR(10) NOT NULL DEFAULT 'pickup',
            order_source VARCHAR(10) NOT NULL DEFAULT 'tablet',
            created_at INT NOT NULL DEFAULT 0,
            INDEX idx_citizenid (citizenid)
        )
    ]])

    LoadRestaurantsFromDB()
end)

-- =========================================================
--  PERMISSÕES
-- =========================================================
local function GetRestaurantByIndex(index)
    return Config.Restaurants[tonumber(index)]
end

local function GetRestaurantByName(name)
    local normalized = name:lower():gsub("%s+", "")
    for i, restaurant in pairs(Config.Restaurants) do
        if restaurant.name:lower():gsub("%s+", "") == normalized then
            return restaurant, i
        end
    end
    return nil
end

-- Lookup sets (job/grau -> true) montados uma única vez na subida do resource.
-- Evita reiterar Config.Restaurants[i].allowedJobs/managerGrades com pairs()
-- em toda checagem de permissão (que roda em quase todo evento do script);
-- vira uma consulta O(1) em vez de O(n) por chamada.
local allowedJobsSet = {}
local managerGradesSet = {}

local function BuildPermissionSets()
    for i, restaurant in pairs(Config.Restaurants) do
        local jobSet = {}
        for _, job in pairs(restaurant.allowedJobs) do
            jobSet[job] = true
        end
        allowedJobsSet[i] = jobSet

        local gradeSet = {}
        for _, grade in pairs(restaurant.managerGrades or {}) do
            gradeSet[grade] = true
        end
        managerGradesSet[i] = gradeSet
    end
end
BuildPermissionSets()

local function CheckRestaurantPermission(source, restaurantIndex)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    local jobSet = allowedJobsSet[tonumber(restaurantIndex)]
    if not jobSet then return false end

    return jobSet[Player.PlayerData.job.name] == true
end

local function CheckManagerPermission(source, restaurantIndex)
    if not CheckRestaurantPermission(source, restaurantIndex) then return false end

    local gradeSet = managerGradesSet[tonumber(restaurantIndex)]
    if not gradeSet then return false end

    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return false end

    return gradeSet[Player.PlayerData.job.grade.level] == true
end

-- Procura um cupom ativo, válido e não esgotado pelo código (case-insensitive)
local function FindActiveCoupon(restaurantIndex, code)
    if not code or code == '' then return nil end
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant or not restaurant.coupons then return nil end

    local normalized = tostring(code):upper():gsub("%s+", "")
    for _, c in pairs(restaurant.coupons) do
        if c.code == normalized and c.active then
            if c.maxUses and c.maxUses > 0 and c.uses >= c.maxUses then return nil end
            if c.expiresAt and c.expiresAt > 0 and os.time() > c.expiresAt then return nil end
            return c
        end
    end
    return nil
end

-- Funcionário "disponível" = está online, com o job do restaurante E com o
-- ponto batido (Player.PlayerData.job.onduty == true).
--
-- OBS: esta função já ignorou job.onduty de propósito, supondo que o
-- servidor usasse um sistema de ponto próprio que não escrevia nesse campo.
-- Não é o caso: o sistema de ponto em uso (mri_Qjobsystem) dispara o evento
-- padrão 'QBCore:ToggleDuty', tratado dentro do próprio qb-core/qbx_core,
-- que atualiza normalmente Player.PlayerData.job.onduty - então essa é sim
-- a fonte de verdade certa aqui. Sem checar onduty, o Totem de
-- autoatendimento nunca liberava o modo autoatendimento depois que todo
-- mundo batia ponto de saída, porque os funcionários continuavam "online
-- com o job", só não estavam mais de plantão.
local function GetOnDutyEmployees(restaurantIndex)
    local jobSet = allowedJobsSet[tonumber(restaurantIndex)]
    if not jobSet then return {} end

    local employees = {}
    local players = QBCore.Functions.GetQBPlayers and QBCore.Functions.GetQBPlayers() or QBCore.Functions.GetPlayers()

    for _, Player in pairs(players) do
        -- GetQBPlayers retorna objetos Player; GetPlayers pode retornar apenas source ids
        local p = Player
        if type(Player) ~= 'table' then
            p = QBCore.Functions.GetPlayer(Player)
        end
        if p and jobSet[p.PlayerData.job.name] and p.PlayerData.job.onduty then
            employees[#employees + 1] = p.PlayerData.source
        end
    end

    return employees
end

-- Quantidade mínima de funcionários de plantão para liberar a opção de entrega
local MIN_EMPLOYEES_FOR_DELIVERY = 2

-- =========================================================
--  MENU / STATUS
-- =========================================================
QBCore.Functions.CreateCallback('rm-restaurant:server:GetAllRestaurants', function(source, cb)
    cb(Config.Restaurants)
end)

-- Usado pela NUI antes de liberar o botão de "Entrega" no modal de checkout
QBCore.Functions.CreateCallback('rm-restaurant:server:CanDeliver', function(source, cb, restaurantIndex)
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant or restaurant.deliveryPaused then
        cb(false)
        return
    end

    local employees = GetOnDutyEmployees(restaurantIndex)
    cb(#employees >= MIN_EMPLOYEES_FOR_DELIVERY)
end)

-- Leitura do estado atual de pausa de entregas (usado pelo toggle na Cozinha)
QBCore.Functions.CreateCallback('rm-restaurant:server:GetDeliveryStatus', function(source, cb, restaurantIndex)
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    cb(restaurant and restaurant.deliveryPaused or false)
end)

-- Funcionário pausa/retoma as entregas do restaurante (ex: equipe ocupada
-- demais pra sair pra entregar). Qualquer funcionário do restaurante pode
-- usar - não é uma ação de gerência.
RegisterNetEvent('rm-restaurant:server:ToggleDelivery', function(restaurantIndex, paused)
    local src = source
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    if not CheckRestaurantPermission(src, restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    restaurant.deliveryPaused = paused and true or false

    TriggerClientEvent('rm-restaurant:client:DeliveryStatusChanged', -1, tonumber(restaurantIndex), restaurant.deliveryPaused)

    Notify(src, restaurant.deliveryPaused and T('success.delivery_paused') or T('success.delivery_resumed'), 'success')
end)

-- Callback dedicado do TOTEM: já decide se pode ser usado (sem nenhum
-- funcionário de plantão) e devolve o cardápio com "isOpen" forçado como
-- true nesse modo autoatendimento - não tem quem abra a loja manualmente
-- se não há ninguém de plantão, então o totem não pode depender disso.
-- Com funcionário de plantão, cb(nil) e o cliente deve usar o balcão.
QBCore.Functions.CreateCallback('rm-restaurant:server:GetTotemMenu', function(source, cb, restaurantIndex)
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then cb(nil) return end

    if #GetOnDutyEmployees(restaurantIndex) > 0 then
        cb(nil)
        return
    end

    cb({
        name = restaurant.name,
        label = restaurant.label,
        isOpen = true, -- modo autoatendimento: sempre "aberto" pro totem
        menu = restaurant.menu,
    })
end)

QBCore.Functions.CreateCallback('rm-restaurant:server:GetMenu', function(source, cb, restaurantIndex)
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then cb(nil) return end
    cb({
        name = restaurant.name,
        label = restaurant.label,
        isOpen = restaurant.isOpen,
        menu = restaurant.menu,
    })
end)

QBCore.Functions.CreateCallback('rm-restaurant:server:HasPermission', function(source, cb, restaurantIndex)
    cb(CheckRestaurantPermission(source, restaurantIndex))
end)

QBCore.Functions.CreateCallback('rm-restaurant:server:HasManagerPermission', function(source, cb, restaurantIndex)
    cb(CheckManagerPermission(source, restaurantIndex))
end)

RegisterNetEvent('rm-restaurant:server:ToggleRestaurant', function(restaurantIndex, state)
    local src = source
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    if not CheckRestaurantPermission(src, restaurantIndex) then
        Notify(src, T('error.not_authorized'), 'error')
        return
    end

    if restaurant.isOpen == state then
        Notify(src, state and T('error.already_open') or T('error.already_closed'), 'error')
        return
    end

    restaurant.isOpen = state
    TriggerClientEvent('rm-restaurant:client:RestaurantStateChanged', -1, restaurantIndex, state)

    Notify(src, state and T('success.restaurant_opened', { restaurant = restaurant.label })
        or T('success.restaurant_closed', { restaurant = restaurant.label }), 'success')

    TriggerClientEvent('QBCore:Notify', -1,
        state and T('info.notification_open', { restaurant = restaurant.label })
        or T('info.notification_closed', { restaurant = restaurant.label }),
        state and 'success' or 'error', Config.NotificationDuration)
end)

RegisterNetEvent('rm-restaurant:server:GetRestaurantsStatus', function()
    local src = source
    TriggerClientEvent('rm-restaurant:client:SyncRestaurants', src, Config.Restaurants)
end)

RegisterNetEvent('rm-restaurant:server:RequestUpdate', function()
    TriggerClientEvent('rm-restaurant:client:SyncRestaurants', -1, Config.Restaurants)
end)

-- =========================================================
--  PEDIDOS (CLIENTE -> COZINHA)
-- =========================================================

-- Devolve os últimos pedidos que o próprio jogador já fez (qualquer
-- restaurante), pra alimentar a aba "Histórico de Pedidos" no tablet e
-- permitir repetir um pedido antigo com 1 clique.
QBCore.Functions.CreateCallback('rm-restaurant:server:GetOrderHistory', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then cb({}) return end

    local rows = MySQL.query.await(
        'SELECT * FROM rm_restaurant_order_history WHERE citizenid = ? ORDER BY created_at DESC LIMIT 30',
        { Player.PlayerData.citizenid }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        local restaurant = GetRestaurantByIndex(row.restaurant_index)
        local ok, decodedItems = pcall(json.decode, row.items or '[]')
        list[#list + 1] = {
            id = row.id,
            orderId = row.order_id,
            restaurantIndex = row.restaurant_index,
            restaurantLabel = restaurant and restaurant.label or ('Restaurante #' .. row.restaurant_index),
            items = (ok and decodedItems) or {},
            total = row.total,
            discount = row.discount,
            couponCode = row.coupon_code,
            orderType = row.order_type,
            orderSource = row.order_source,
            createdAt = row.created_at,
        }
    end
    cb(list)
end)

-- cart = { {id = menuItemId, qty = number}, ... }
-- orderType = 'pickup' | 'delivery'
-- deliveryCoords = { x = , y = , z = } (só quando orderType == 'delivery', capturado no cliente na hora do checkout)
-- couponCode = código do cupom de desconto aplicado no carrinho (opcional)
-- orderSource = 'tablet' | 'totem' (de onde o pedido foi feito; só informativo pra cozinha)
RegisterNetEvent('rm-restaurant:server:PlaceOrder', function(restaurantIndex, cart, orderType, deliveryCoords, couponCode, orderSource)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    orderSource = (orderSource == 'totem') and 'totem' or 'tablet'

    local onDutyCount = #GetOnDutyEmployees(restaurantIndex)

    -- Totem só pode ser usado quando não há funcionário de plantão (ver
    -- Config/GetTotemMenu). A NUI já bloqueia o acesso antes disso, mas o
    -- servidor revalida aqui pra não depender só do client.
    if orderSource == 'totem' and onDutyCount > 0 then
        Notify(src, T('error.totem_staff_online'), 'error')
        return
    end

    -- Sem ninguém de plantão, o totem funciona em modo autoatendimento e
    -- ignora o status manual de aberto/fechado - não tem quem abra a loja
    -- nesse cenário, então travar aqui deixaria o totem inutilizável.
    local isTotemAutoMode = orderSource == 'totem' and onDutyCount == 0

    if not restaurant.isOpen and not isTotemAutoMode then
        Notify(src, T('error.restaurant_closed_order'), 'error')
        return
    end

    if not cart or #cart == 0 then
        Notify(src, T('error.invalid_cart'), 'error')
        return
    end

    orderType = (orderType == 'delivery') and 'delivery' or 'pickup'

    -- Retirada pelo tablet pode ser desabilitada em Config.EnableTabletPickupOrders
    -- (ex: quando o Atendimento de Balcão passa a cobrir esse caso). Não afeta
    -- pedidos feitos pelo Totem, que continuam permitindo retirada normalmente.
    if orderSource == 'tablet' and orderType == 'pickup' and Config.EnableTabletPickupOrders == false then
        Notify(src, T('error.pickup_disabled_use_counter'), 'error')
        return
    end

    if orderType == 'delivery' and (not deliveryCoords or not deliveryCoords.x) then
        -- sem coordenadas não dá pra tracejar rota; volta pra retirada por segurança
        orderType = 'pickup'
    end

    -- Entrega exige um número mínimo de funcionários de plantão; revalidado aqui
    -- pois o botão da NUI já é desabilitado, mas o servidor é sempre a fonte da verdade.
    if orderType == 'delivery' and #GetOnDutyEmployees(restaurantIndex) < MIN_EMPLOYEES_FOR_DELIVERY then
        Notify(src, T('error.delivery_needs_two_employees'), 'error')
        orderType = 'pickup'
    end

    -- Funcionário pode pausar entregas manualmente (ex: equipe ocupada); revalidado
    -- aqui pelo mesmo motivo do bloco acima.
    if orderType == 'delivery' and restaurant.deliveryPaused then
        Notify(src, T('error.delivery_paused_by_staff'), 'error')
        orderType = 'pickup'
    end

    -- Validar itens, estoque e calcular total
    local orderItems = {}
    local total = 0

    for _, cartLine in pairs(cart) do
        local menuItem = nil
        for _, mi in pairs(restaurant.menu) do
            if mi.id == cartLine.id then menuItem = mi break end
        end

        if not menuItem or not menuItem.enabled then
            Notify(src, T('error.item_out_of_stock'), 'error')
            return
        end

        local qty = math.max(1, tonumber(cartLine.qty) or 1)

        if menuItem.stock < qty then
            Notify(src, T('error.item_out_of_stock'), 'error')
            return
        end

        orderItems[#orderItems + 1] = {
            id = menuItem.id,
            name = menuItem.name,
            item = menuItem.item,
            price = menuItem.price,
            qty = qty,
            prepTime = menuItem.prepTime,
            recipe = menuItem.recipe or {},
        }

        total = total + (menuItem.price * qty)
    end

    -- Aplicar cupom de desconto, se informado e válido
    local appliedCoupon = nil
    local discount = 0
    if couponCode and couponCode ~= '' then
        appliedCoupon = FindActiveCoupon(restaurantIndex, couponCode)
        if not appliedCoupon then
            Notify(src, T('error.invalid_coupon'), 'error')
            return
        end

        if appliedCoupon.type == 'percent' then
            discount = math.floor(total * (appliedCoupon.value / 100))
        else
            discount = math.min(total, appliedCoupon.value)
        end
        total = math.max(0, total - discount)
    end

    -- Sem ninguém de plantão pra preparar? Se o pedido veio do TOTEM, ele
    -- pula a cozinha inteira e é entregue automaticamente (ver Config.TotemAutoDeliverWhenNoStaff)
    local autoDeliver = isTotemAutoMode and Config.TotemAutoDeliverWhenNoStaff ~= false

    -- Verificar pagamento
    local method = Config.PaymentMethod
    local hasMoney = false
    local payFrom = nil

    if method == 'cash' or method == 'both' then
        if Player.PlayerData.money['cash'] >= total then
            hasMoney = true
            payFrom = 'cash'
        end
    end
    if not hasMoney and (method == 'bank' or method == 'both') then
        if Player.PlayerData.money['bank'] >= total then
            hasMoney = true
            payFrom = 'bank'
        end
    end

    if not hasMoney then
        Notify(src, T('error.insufficient_money'), 'error')
        return
    end

    Player.Functions.RemoveMoney(payFrom, total, 'rm-restaurant-order')

    if autoDeliver then
        -- Sem funcionário de plantão: dá o item direto no inventário do
        -- cliente, na hora, sem passar por pending/preparing/ready.
        local deliveryOk = true
        for _, orderItem in pairs(orderItems) do
            local given = Inventory.AddItem(src, orderItem.item, orderItem.qty)
            if given == false then
                deliveryOk = false
                break
            end
        end

        if not deliveryOk then
            -- Não deu pra entregar (ex: inventário cheio) - estorna o dinheiro
            -- e não mexe em estoque/caixa, como se o pedido nunca tivesse acontecido.
            Player.Functions.AddMoney(payFrom, total, 'rm-restaurant-refund')
            Notify(src, T('error.totem_auto_deliver_failed'), 'error')
            return
        end

        -- Debitar estoque
        for _, orderItem in pairs(orderItems) do
            for _, mi in pairs(restaurant.menu) do
                if mi.id == orderItem.id then
                    mi.stock = mi.stock - orderItem.qty
                    PersistMenuItem(restaurantIndex, mi)
                end
            end
        end

        -- Creditar caixa do restaurante (sem comissão: não tem funcionário
        -- de plantão pra receber, o valor inteiro fica pro caixa)
        restaurant.balance = restaurant.balance + total
        PersistBalance(restaurantIndex, restaurant.balance)

        if appliedCoupon then
            appliedCoupon.uses = (appliedCoupon.uses or 0) + 1
            IncrementCouponUse(appliedCoupon.id)
        end

        OrderIdCounter = OrderIdCounter + 1
        local order = {
            id = OrderIdCounter,
            restaurantIndex = tonumber(restaurantIndex),
            items = orderItems,
            total = total,
            discount = discount,
            couponCode = appliedCoupon and appliedCoupon.code or nil,
            customerId = src,
            customerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
            status = 'completed', -- já nasce concluído: não passa pela cozinha
            orderType = 'pickup',
            orderSource = orderSource, -- 'totem'
            autoDelivered = true,
            deliveryCoords = nil,
            payFrom = payFrom,
            createdAt = os.time(),
        }
        Orders[order.id] = order

        -- Registra a venda igual a um pedido normal concluído, só que sem
        -- funcionário vinculado (pra aparecer certinho no log de vendas do gerente)
        PersistSale({
            orderId = order.id,
            restaurantIndex = order.restaurantIndex,
            employeeId = nil,
            employeeName = 'Totem (Automático)',
            customerName = order.customerName,
            items = order.items,
            total = order.total,
            createdAt = order.createdAt,
        })
        RecordOrderHistory(order, Player.PlayerData.citizenid)

        Notify(src, T('success.totem_auto_delivered'), 'success')
        return
    end

    -- Debitar estoque
    for _, orderItem in pairs(orderItems) do
        for _, mi in pairs(restaurant.menu) do
            if mi.id == orderItem.id then
                mi.stock = mi.stock - orderItem.qty
                PersistMenuItem(restaurantIndex, mi)
            end
        end
    end

    -- Creditar caixa do restaurante
    restaurant.balance = restaurant.balance + total
    PersistBalance(restaurantIndex, restaurant.balance)

    OrderIdCounter = OrderIdCounter + 1
    local order = {
        id = OrderIdCounter,
        restaurantIndex = tonumber(restaurantIndex),
        items = orderItems,
        total = total,
        discount = discount,
        couponCode = appliedCoupon and appliedCoupon.code or nil,
        customerId = src,
        customerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname,
        status = 'pending', -- pending -> preparing -> ready -> completed
        orderType = orderType, -- 'pickup' | 'delivery'
        orderSource = orderSource, -- 'tablet' | 'totem'
        deliveryCoords = orderType == 'delivery' and deliveryCoords or nil,
        payFrom = payFrom, -- 'cash' | 'bank', usado pro estorno em CancelOrder
        createdAt = os.time(),
    }
    Orders[order.id] = order

    if appliedCoupon then
        appliedCoupon.uses = (appliedCoupon.uses or 0) + 1
        IncrementCouponUse(appliedCoupon.id)
    end

    RecordOrderHistory(order, Player.PlayerData.citizenid)

    Notify(src, T('success.order_placed'), 'success')

    -- Avisar cozinha (funcionários de plantão)
    local employees = GetOnDutyEmployees(restaurantIndex)
    for _, employeeSrc in pairs(employees) do
        TriggerClientEvent('rm-restaurant:client:NewOrder', employeeSrc, order, restaurant.label)
    end
end)

-- =========================================================
--  PEDIDO DE BALCÃO (ATENDIMENTO)
--  Registrado pelo próprio FUNCIONÁRIO na aba "Atendimento", pra um
--  cliente que está fisicamente na frente dele (sem usar tablet/totem).
--  O funcionário seleciona o cliente mais próximo (customerId) e monta
--  o pedido, mas o dinheiro NÃO é debitado automaticamente: o cliente
--  recebe uma solicitação de cobrança (aceitar/recusar) e só depois
--  que ele confirma é que o valor sai da conta dele e o pedido segue
--  pra cozinha. Tudo revalidado no servidor, nunca confia só no client.
-- =========================================================

local PendingCounterCharges = {} -- [requestId] = { ...dados do pedido pendente de confirmação }
local ChargeRequestCounter = 0
local CHARGE_REQUEST_TIMEOUT = 30 -- segundos que o cliente tem pra aceitar/recusar a cobrança

-- cart = { {id = menuItemId, qty = number}, ... }
-- customerId = server id do cliente selecionado (via target no balcão)
-- couponCode = código do cupom de desconto que o funcionário aplicou no pedido (opcional)
RegisterNetEvent('rm-restaurant:server:PlaceCounterOrder', function(restaurantIndex, cart, customerId, couponCode)
    local src = source

    if not CheckRestaurantPermission(src, restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    if not restaurant.isOpen then
        Notify(src, T('error.restaurant_closed_order'), 'error')
        return
    end

    if not cart or #cart == 0 then
        Notify(src, T('error.invalid_cart'), 'error')
        return
    end

    local customer = QBCore.Functions.GetPlayer(tonumber(customerId))
    if not customer then
        Notify(src, T('error.customer_offline'), 'error')
        return
    end

    -- Revalida a distância no servidor - o client só sugere o mais próximo,
    -- quem garante que não dá pra montar um pedido pra alguém longe é aqui.
    local employeePed = GetPlayerPed(src)
    local customerPed = GetPlayerPed(tonumber(customerId))
    local dist = #(GetEntityCoords(employeePed) - GetEntityCoords(customerPed))
    if dist > (Config.CounterCustomerMaxDistance or 5.0) then
        Notify(src, T('error.customer_too_far'), 'error')
        return
    end

    -- Validar itens, estoque e calcular total (mesma regra do PlaceOrder normal)
    local orderItems = {}
    local total = 0

    for _, cartLine in pairs(cart) do
        local menuItem = nil
        for _, mi in pairs(restaurant.menu) do
            if mi.id == cartLine.id then menuItem = mi break end
        end

        if not menuItem or not menuItem.enabled then
            Notify(src, T('error.item_out_of_stock'), 'error')
            return
        end

        local qty = math.max(1, tonumber(cartLine.qty) or 1)

        if menuItem.stock < qty then
            Notify(src, T('error.item_out_of_stock'), 'error')
            return
        end

        orderItems[#orderItems + 1] = {
            id = menuItem.id,
            name = menuItem.name,
            item = menuItem.item,
            price = menuItem.price,
            qty = qty,
            prepTime = menuItem.prepTime,
            recipe = menuItem.recipe or {},
        }

        total = total + (menuItem.price * qty)
    end

    -- Aplicar cupom de desconto, se o funcionário informou um no balcão
    -- (mesma regra do PlaceOrder normal)
    local appliedCoupon = nil
    local discount = 0
    if couponCode and couponCode ~= '' then
        appliedCoupon = FindActiveCoupon(restaurantIndex, couponCode)
        if not appliedCoupon then
            Notify(src, T('error.invalid_coupon'), 'error')
            return
        end

        if appliedCoupon.type == 'percent' then
            discount = math.floor(total * (appliedCoupon.value / 100))
        else
            discount = math.min(total, appliedCoupon.value)
        end
        total = math.max(0, total - discount)
    end

    -- NÃO cobra na hora. Guarda o pedido montado como "pendente de
    -- confirmação" e manda uma solicitação de cobrança pro cliente. O
    -- dinheiro só sai da conta dele se ele aceitar (evento abaixo).
    ChargeRequestCounter = ChargeRequestCounter + 1
    local requestId = ChargeRequestCounter

    PendingCounterCharges[requestId] = {
        id = requestId,
        restaurantIndex = tonumber(restaurantIndex),
        employeeSrc = src,
        customerSrc = customer.PlayerData.source,
        orderItems = orderItems,
        total = total,
        discount = discount,
        couponId = appliedCoupon and appliedCoupon.id or nil,
        couponCode = appliedCoupon and appliedCoupon.code or nil,
        resolved = false,
    }

    TriggerClientEvent('rm-restaurant:client:CounterChargeRequest', customer.PlayerData.source, {
        requestId = requestId,
        restaurant = restaurant.label,
        total = total,
    })

    Notify(src, T('success.charge_request_sent'), 'primary')

    -- Se o cliente não responder em tempo hábil, cancela automaticamente
    CreateThread(function()
        Wait(CHARGE_REQUEST_TIMEOUT * 1000)
        local pending = PendingCounterCharges[requestId]
        if pending and not pending.resolved then
            pending.resolved = true
            PendingCounterCharges[requestId] = nil
            Notify(pending.employeeSrc, T('error.charge_request_timeout'), 'error')
            TriggerClientEvent('rm-restaurant:client:CounterChargeExpired', pending.customerSrc, requestId)
        end
    end)
end)

-- Resposta do cliente à solicitação de cobrança (aceitar/recusar). Só o
-- próprio cliente selecionado pode responder a própria cobrança - o
-- servidor nunca confia em quem disparou o evento sem checar a origem.
RegisterNetEvent('rm-restaurant:server:CounterChargeResponse', function(requestId, accepted)
    local src = source
    local pending = PendingCounterCharges[requestId]

    if not pending or pending.resolved then return end
    if pending.customerSrc ~= src then return end

    pending.resolved = true
    PendingCounterCharges[requestId] = nil

    if not accepted then
        Notify(pending.employeeSrc, T('error.charge_declined_by_customer'), 'error')
        Notify(src, T('info.customer_declined_charge'), 'primary')
        return
    end

    local restaurant = GetRestaurantByIndex(pending.restaurantIndex)
    if not restaurant or not restaurant.isOpen then
        Notify(pending.employeeSrc, T('error.restaurant_closed_order'), 'error')
        Notify(src, T('error.charge_request_invalid'), 'error')
        return
    end

    local customer = QBCore.Functions.GetPlayer(src)
    if not customer then return end

    -- Revalida a distância na hora de aceitar - o cliente pode ter saído
    -- do balcão entre o pedido montado e a confirmação.
    local employeePed = GetPlayerPed(pending.employeeSrc)
    if not employeePed or employeePed == 0 then
        Notify(src, T('error.charge_request_invalid'), 'error')
        return
    end

    local customerPed = GetPlayerPed(src)
    local dist = #(GetEntityCoords(employeePed) - GetEntityCoords(customerPed))
    if dist > (Config.CounterCustomerMaxDistance or 5.0) then
        Notify(pending.employeeSrc, T('error.customer_too_far'), 'error')
        Notify(src, T('error.customer_too_far'), 'error')
        return
    end

    -- Revalida estoque - pode ter mudado entre o pedido montado e a confirmação
    for _, orderItem in pairs(pending.orderItems) do
        local menuItem = nil
        for _, mi in pairs(restaurant.menu) do
            if mi.id == orderItem.id then menuItem = mi break end
        end
        if not menuItem or not menuItem.enabled or menuItem.stock < orderItem.qty then
            Notify(pending.employeeSrc, T('error.item_out_of_stock'), 'error')
            Notify(src, T('error.item_out_of_stock'), 'error')
            return
        end
    end

    -- Cobrar o cliente (mesma regra de pagamento do PlaceOrder normal)
    local total = pending.total
    local method = Config.PaymentMethod
    local hasMoney = false
    local payFrom = nil

    if method == 'cash' or method == 'both' then
        if customer.PlayerData.money['cash'] >= total then
            hasMoney = true
            payFrom = 'cash'
        end
    end
    if not hasMoney and (method == 'bank' or method == 'both') then
        if customer.PlayerData.money['bank'] >= total then
            hasMoney = true
            payFrom = 'bank'
        end
    end

    if not hasMoney then
        Notify(pending.employeeSrc, T('error.customer_insufficient_money'), 'error')
        Notify(src, T('error.insufficient_money'), 'error')
        return
    end

    customer.Functions.RemoveMoney(payFrom, total, 'rm-restaurant-counter-order')

    -- Debitar estoque
    for _, orderItem in pairs(pending.orderItems) do
        for _, mi in pairs(restaurant.menu) do
            if mi.id == orderItem.id then
                mi.stock = mi.stock - orderItem.qty
                PersistMenuItem(pending.restaurantIndex, mi)
            end
        end
    end

    -- Creditar caixa do restaurante (agora com dinheiro de verdade, já
    -- descontado do cliente selecionado acima)
    restaurant.balance = restaurant.balance + total
    PersistBalance(pending.restaurantIndex, restaurant.balance)

    OrderIdCounter = OrderIdCounter + 1
    local order = {
        id = OrderIdCounter,
        restaurantIndex = pending.restaurantIndex,
        items = pending.orderItems,
        total = total,
        discount = pending.discount,
        couponCode = pending.couponCode,
        customerId = customer.PlayerData.source,
        customerName = customer.PlayerData.charinfo.firstname .. ' ' .. customer.PlayerData.charinfo.lastname,
        status = 'pending', -- segue o fluxo normal: pending -> preparing -> ready -> completed
        orderType = 'pickup', -- balcão é sempre retirada no local
        orderSource = 'counter', -- 'tablet' | 'totem' | 'counter'
        deliveryCoords = nil,
        payFrom = payFrom, -- 'cash' | 'bank', usado pro estorno em CancelOrder
        createdAt = os.time(),
    }
    Orders[order.id] = order

    if pending.couponId then
        for _, c in pairs(restaurant.coupons or {}) do
            if c.id == pending.couponId then
                c.uses = (c.uses or 0) + 1
                break
            end
        end
        IncrementCouponUse(pending.couponId)
    end

    Notify(pending.employeeSrc, T('success.counter_order_registered', { total = total, id = order.id }), 'success')
    Notify(src, T('info.counter_charged', { amount = total, restaurant = restaurant.label }), 'primary')

    -- Avisar cozinha (funcionários de plantão), igual pedido normal
    local employees = GetOnDutyEmployees(pending.restaurantIndex)
    for _, employeeSrc in pairs(employees) do
        TriggerClientEvent('rm-restaurant:client:NewOrder', employeeSrc, order, restaurant.label)
    end
end)

QBCore.Functions.CreateCallback('rm-restaurant:server:GetKitchenOrders', function(source, cb, restaurantIndex)
    if not CheckRestaurantPermission(source, restaurantIndex) then
        cb(nil)
        return
    end

    local list = {}
    for _, order in pairs(Orders) do
        if order.restaurantIndex == tonumber(restaurantIndex) and order.status ~= 'completed' and order.status ~= 'cancelled' then
            list[#list + 1] = order
        end
    end

    table.sort(list, function(a, b) return a.createdAt < b.createdAt end)
    cb(list)
end)

-- Usado pela "missão de preparo": recebe uma lista de nomes de item e devolve
-- quantas unidades o próprio funcionário (source) tem de cada um no inventário.
QBCore.Functions.CreateCallback('rm-restaurant:server:GetRecipeItemCounts', function(source, cb, items)
    local counts = {}
    if type(items) == 'table' then
        for _, itemName in ipairs(items) do
            if itemName and itemName ~= '' then
                counts[itemName] = Inventory.GetItemCount(source, itemName)
            end
        end
    end
    cb(counts)
end)

RegisterNetEvent('rm-restaurant:server:AcceptOrder', function(orderId)
    local src = source
    local order = Orders[orderId]
    if not order then Notify(src, T('error.order_not_found'), 'error') return end

    if not CheckRestaurantPermission(src, order.restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    if order.status ~= 'pending' then
        Notify(src, T('error.order_not_ready'), 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    order.status = 'preparing'
    order.employeeId = src
    order.employeeName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Funcionário'

    TriggerClientEvent('rm-restaurant:client:OrderUpdated', -1, order)
    Notify(src, T('success.order_accepted', { id = order.id }), 'success')
end)

RegisterNetEvent('rm-restaurant:server:MarkOrderReady', function(orderId)
    local src = source
    local order = Orders[orderId]
    if not order then Notify(src, T('error.order_not_found'), 'error') return end

    if not CheckRestaurantPermission(src, order.restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    if order.status ~= 'preparing' then
        Notify(src, T('error.order_not_ready'), 'error')
        return
    end

    if order.employeeId ~= src then
        Notify(src, 'Apenas o funcionário que aceitou este pedido pode marcá-lo como pronto', 'error')
        return
    end

    order.status = 'ready'
    TriggerClientEvent('rm-restaurant:client:OrderUpdated', -1, order)

    local restaurant = GetRestaurantByIndex(order.restaurantIndex)
    if order.customerId then
        TriggerClientEvent('QBCore:Notify', order.customerId,
            T('success.order_ready', { restaurant = restaurant.label }), 'success', Config.NotificationDuration)
        TriggerClientEvent('rm-restaurant:client:OrderReady', order.customerId, order)
    end

    -- Pedido de entrega: assim que o funcionário termina o preparo, o GPS dele
    -- já é atualizado automaticamente com o destino do cliente que fez o pedido.
    if order.orderType == 'delivery' and order.deliveryCoords then
        TriggerClientEvent('rm-restaurant:client:SetDeliveryWaypoint', src, order.deliveryCoords, order.id)
    end
end)

-- Confirmação de entrega: o funcionário entrega o pedido manualmente (RP) e só então
-- clica para confirmar. Esse clique é o que efetiva o registro da venda.
RegisterNetEvent('rm-restaurant:server:CompleteOrder', function(orderId)
    local src = source
    local order = Orders[orderId]
    if not order then Notify(src, T('error.order_not_found'), 'error') return end

    if not CheckRestaurantPermission(src, order.restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    if order.status ~= 'ready' then
        Notify(src, T('error.order_not_ready'), 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    local employeeName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Funcionário'

    order.status = 'completed'
    order.employeeId = src
    order.employeeName = employeeName
    TriggerClientEvent('rm-restaurant:client:OrderUpdated', -1, order)

    -- Comissão do funcionário: uma parte do valor (já creditado no caixa
    -- quando o pedido foi feito) sai do caixa e vai direto pro funcionário
    -- que confirmou a entrega. O restante fica no caixa pro dono sacar.
    local restaurant = GetRestaurantByIndex(order.restaurantIndex)
    local commissionPercent = math.max(0, math.min(100, Config.EmployeeCommissionPercent or 0))
    local employeeCut = math.floor(order.total * (commissionPercent / 100))

    if restaurant and employeeCut > 0 then
        restaurant.balance = math.max(0, restaurant.balance - employeeCut)
        PersistBalance(order.restaurantIndex, restaurant.balance)

        if Player then
            Player.Functions.AddMoney(Config.EmployeeCommissionMoneyType or 'cash', employeeCut, 'rm-restaurant-commission')
        end

        Notify(src, T('success.commission_received', { amount = employeeCut, id = order.id }), 'success')
        TriggerClientEvent('rm-restaurant:client:BalanceUpdated', -1, order.restaurantIndex, restaurant.balance)
    end

    -- Registrar venda (só criada quando o funcionário confirma que entregou)
    local sale = {
        orderId = order.id,
        restaurantIndex = order.restaurantIndex,
        employeeId = src,
        employeeName = employeeName,
        customerName = order.customerName,
        items = order.items,
        total = order.total,
        createdAt = os.time(),
    }
    PersistSale(sale)

    Notify(src, T('success.order_delivered', { id = order.id }), 'success')
end)

RegisterNetEvent('rm-restaurant:server:CancelOrder', function(orderId)
    local src = source
    local order = Orders[orderId]
    if not order then return end

    if not CheckRestaurantPermission(src, order.restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    -- Estornar estoque
    local restaurant = GetRestaurantByIndex(order.restaurantIndex)
    if restaurant then
        for _, orderItem in pairs(order.items) do
            for _, mi in pairs(restaurant.menu) do
                if mi.id == orderItem.id then
                    mi.stock = mi.stock + orderItem.qty
                    PersistMenuItem(order.restaurantIndex, mi)
                end
            end
        end
        restaurant.balance = math.max(0, restaurant.balance - order.total)
        PersistBalance(order.restaurantIndex, restaurant.balance)
    end

    -- Estornar dinheiro ao cliente, se online
    local customer = QBCore.Functions.GetPlayer(order.customerId)
    if customer then
        customer.Functions.AddMoney(order.payFrom or 'cash', order.total, 'rm-restaurant-refund')
    end

    order.status = 'cancelled'
    TriggerClientEvent('rm-restaurant:client:OrderUpdated', -1, order)
end)

-- =========================================================
--  VENDAS REALIZADAS (somente gerente/dono visualiza)
-- =========================================================
QBCore.Functions.CreateCallback('rm-restaurant:server:GetSalesLog', function(source, cb, restaurantIndex)
    if not CheckManagerPermission(source, restaurantIndex) then
        cb(nil)
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM rm_restaurant_sales WHERE restaurant_index = ? ORDER BY created_at DESC LIMIT 100',
        { tonumber(restaurantIndex) }
    )

    local list = {}
    for _, row in ipairs(rows or {}) do
        list[#list + 1] = {
            id = row.id,
            orderId = row.order_id,
            restaurantIndex = row.restaurant_index,
            employeeId = row.employee_id,
            employeeName = row.employee_name,
            customerName = row.customer_name,
            items = json.decode(row.items) or {},
            total = row.total,
            createdAt = row.created_at,
        }
    end
    cb(list)
end)

-- Agrega todas as vendas registradas do restaurante por item vendido (quantidade
-- total), usado pelo gráfico de pizza da aba Dashboard em Gerenciar.
QBCore.Functions.CreateCallback('rm-restaurant:server:GetItemsSoldStats', function(source, cb, restaurantIndex)
    if not CheckManagerPermission(source, restaurantIndex) then
        cb(nil)
        return
    end

    local rows = MySQL.query.await(
        'SELECT items FROM rm_restaurant_sales WHERE restaurant_index = ?',
        { tonumber(restaurantIndex) }
    )

    local totals = {}
    local order = {}
    for _, row in ipairs(rows or {}) do
        local ok, items = pcall(json.decode, row.items)
        if ok and type(items) == 'table' then
            for _, item in pairs(items) do
                local name = item.name or 'Item'
                if not totals[name] then
                    totals[name] = 0
                    order[#order + 1] = name
                end
                totals[name] = totals[name] + (tonumber(item.qty) or 0)
            end
        end
    end

    local list = {}
    for _, name in ipairs(order) do
        list[#list + 1] = { name = name, qty = totals[name] }
    end

    table.sort(list, function(a, b) return a.qty > b.qty end)
    cb(list)
end)

-- =========================================================
--  ESTOQUE (qualquer funcionário pode abastecer/retirar)
--  O registro de movimentações agora fica visível somente na
--  aba Gerenciar (dono/gerente), veja rm-restaurant:server:GetStockLog
-- =========================================================
local function AddStockLogEntry(restaurantIndex, employeeName, itemName, action, qty)
    local createdAt = os.time()
    PersistStockLogEntry(restaurantIndex, employeeName, itemName, action, qty, createdAt)
    return createdAt
end

-- Usado pela página de Estoque (qualquer funcionário) - só os itens, sem o log
QBCore.Functions.CreateCallback('rm-restaurant:server:GetStockData', function(source, cb, restaurantIndex)
    if not CheckRestaurantPermission(source, restaurantIndex) then
        cb(nil)
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then cb(nil) return end

    cb({
        name = restaurant.name,
        label = restaurant.label,
        menu = restaurant.menu,
    })
end)

-- Usado pela aba Gerenciar > Registro de Estoque (somente dono/gerente)
QBCore.Functions.CreateCallback('rm-restaurant:server:GetStockLog', function(source, cb, restaurantIndex)
    if not CheckManagerPermission(source, restaurantIndex) then
        cb(nil)
        return
    end

    local rows = MySQL.query.await(
        'SELECT * FROM rm_restaurant_stocklog WHERE restaurant_index = ? ORDER BY created_at DESC LIMIT 100',
        { tonumber(restaurantIndex) }
    )

    local log = {}
    for _, row in ipairs(rows or {}) do
        log[#log + 1] = {
            id = row.id,
            employeeName = row.employee_name,
            item = row.item_name,
            action = row.action,
            qty = row.qty,
            createdAt = row.created_at,
        }
    end
    cb(log)
end)

RegisterNetEvent('rm-restaurant:server:AddStock', function(restaurantIndex, itemId, qty)
    local src = source
    if not CheckRestaurantPermission(src, restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    qty = math.max(1, tonumber(qty) or 0)
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    local menuItem = nil
    for _, mi in pairs(restaurant.menu) do
        if mi.id == itemId then menuItem = mi break end
    end
    if not menuItem then return end

    local have = Inventory.GetItemCount(src, menuItem.item)
    if have < qty then
        Notify(src, T('error.missing_crafted_items', { items = menuItem.name }), 'error')
        return
    end

    local removed = Inventory.RemoveItem(src, menuItem.item, qty)
    if removed == false then
        Notify(src, T('error.missing_crafted_items', { items = menuItem.name }), 'error')
        return
    end

    menuItem.stock = menuItem.stock + qty
    PersistMenuItem(restaurantIndex, menuItem)

    local Player = QBCore.Functions.GetPlayer(src)
    local employeeName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Funcionário'
    AddStockLogEntry(restaurantIndex, employeeName, menuItem.name, 'add', qty)

    Notify(src, T('success.stock_updated'), 'success')
    TriggerClientEvent('rm-restaurant:client:MenuUpdated', -1, tonumber(restaurantIndex), restaurant.menu)
    TriggerClientEvent('rm-restaurant:client:StockLogUpdated', -1, tonumber(restaurantIndex))
end)

RegisterNetEvent('rm-restaurant:server:RemoveStock', function(restaurantIndex, itemId, qty)
    local src = source
    if not CheckRestaurantPermission(src, restaurantIndex) then
        Notify(src, T('error.not_employee'), 'error')
        return
    end

    qty = math.max(1, tonumber(qty) or 0)
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    local menuItem = nil
    for _, mi in pairs(restaurant.menu) do
        if mi.id == itemId then menuItem = mi break end
    end
    if not menuItem then return end

    if menuItem.stock < qty then
        Notify(src, T('error.item_out_of_stock'), 'error')
        return
    end

    local given = Inventory.AddItem(src, menuItem.item, qty)
    if given == false then
        Notify(src, 'Não foi possível colocar o item no seu inventário (verifique peso/espaço)', 'error')
        return
    end

    menuItem.stock = menuItem.stock - qty
    PersistMenuItem(restaurantIndex, menuItem)

    local Player = QBCore.Functions.GetPlayer(src)
    local employeeName = Player and (Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname) or 'Funcionário'
    AddStockLogEntry(restaurantIndex, employeeName, menuItem.name, 'remove', qty)

    Notify(src, T('success.stock_updated'), 'success')
    TriggerClientEvent('rm-restaurant:client:MenuUpdated', -1, tonumber(restaurantIndex), restaurant.menu)
    TriggerClientEvent('rm-restaurant:client:StockLogUpdated', -1, tonumber(restaurantIndex))
end)

-- =========================================================
--  GERÊNCIA (CARDÁPIO E CAIXA)
-- =========================================================
QBCore.Functions.CreateCallback('rm-restaurant:server:GetManagementData', function(source, cb, restaurantIndex)
    if not CheckManagerPermission(source, restaurantIndex) then
        cb(nil)
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    cb({
        name = restaurant.name,
        label = restaurant.label,
        isOpen = restaurant.isOpen,
        menu = restaurant.menu,
        balance = restaurant.balance,
    })
end)

RegisterNetEvent('rm-restaurant:server:UpdateMenuItem', function(restaurantIndex, itemId, changes)
    local src = source
    if not CheckManagerPermission(src, restaurantIndex) then
        Notify(src, T('error.not_manager'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    for _, mi in pairs(restaurant.menu) do
        if mi.id == itemId then
            if changes.price ~= nil then mi.price = math.max(0, tonumber(changes.price) or mi.price) end
            if changes.stock ~= nil then mi.stock = math.max(0, tonumber(changes.stock) or mi.stock) end
            if changes.enabled ~= nil then mi.enabled = changes.enabled and true or false end
            PersistMenuItem(restaurantIndex, mi)
            break
        end
    end

    Notify(src, T('success.item_updated'), 'success')
    TriggerClientEvent('rm-restaurant:client:MenuUpdated', -1, restaurantIndex, restaurant.menu)
end)

-- Dono/gerente cria um novo item de cardápio direto pelo painel de gerência
RegisterNetEvent('rm-restaurant:server:CreateMenuItem', function(restaurantIndex, data)
    local src = source
    if not CheckManagerPermission(src, restaurantIndex) then
        Notify(src, T('error.not_manager'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    if not data or not data.name or data.name == '' or not data.category or data.category == ''
        or not data.item or data.item == '' then
        Notify(src, T('error.invalid_item_data'), 'error')
        return
    end

    local newId = 0
    for _, mi in pairs(restaurant.menu) do
        if mi.id > newId then newId = mi.id end
    end
    newId = newId + 1

    local newItem = {
        id = newId,
        category = tostring(data.category),
        name = tostring(data.name),
        description = tostring(data.description or ''),
        price = math.max(0, tonumber(data.price) or 0),
        item = tostring(data.item),
        image = (data.image and data.image ~= '') and tostring(data.image) or 'img/placeholder-item.png',
        enabled = true,
        stock = math.max(0, tonumber(data.stock) or 0),
        prepTime = math.max(0, tonumber(data.prepTime) or 10),
        recipe = {}, -- sem receita definida ainda; pode ser cadastrada depois direto no banco
    }

    local ok = MySQL.insert.await(
        'INSERT INTO rm_restaurant_menu (restaurant_index, item_id, category, name, description, price, item, image, enabled, stock, prep_time, recipe) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        { tonumber(restaurantIndex), newItem.id, newItem.category, newItem.name, newItem.description, newItem.price, newItem.item, newItem.image, 1, newItem.stock, newItem.prepTime, json.encode(newItem.recipe) }
    )

    if not ok then
        Notify(src, T('error.item_creation_failed'), 'error')
        return
    end

    table.insert(restaurant.menu, newItem)

    Notify(src, T('success.item_created', { item = newItem.name }), 'success')
    TriggerClientEvent('rm-restaurant:client:MenuUpdated', -1, tonumber(restaurantIndex), restaurant.menu)
end)

RegisterNetEvent('rm-restaurant:server:WithdrawTill', function(restaurantIndex, amount)
    local src = source
    if not CheckManagerPermission(src, restaurantIndex) then
        Notify(src, T('error.not_manager'), 'error')
        return
    end

    amount = tonumber(amount)
    if not amount or amount <= 0 then
        Notify(src, T('error.withdraw_invalid'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant or restaurant.balance < amount then
        Notify(src, T('error.withdraw_insufficient_funds'), 'error')
        return
    end

    local Player = QBCore.Functions.GetPlayer(src)
    restaurant.balance = restaurant.balance - amount
    PersistBalance(restaurantIndex, restaurant.balance)
    Player.Functions.AddMoney('cash', amount, 'rm-restaurant-withdraw')

    Notify(src, T('success.withdraw_success', { amount = amount }), 'success')
    TriggerClientEvent('rm-restaurant:client:BalanceUpdated', src, restaurantIndex, restaurant.balance)
end)

-- =========================================================
--  CUPONS DE DESCONTO (GERÊNCIA)
-- =========================================================
QBCore.Functions.CreateCallback('rm-restaurant:server:GetCoupons', function(source, cb, restaurantIndex)
    if not CheckManagerPermission(source, restaurantIndex) then
        cb(nil)
        return
    end
    local restaurant = GetRestaurantByIndex(restaurantIndex)
    cb(restaurant and restaurant.coupons or {})
end)

-- Usado pelo cliente no carrinho, pra validar/pré-visualizar o desconto antes de finalizar o pedido
QBCore.Functions.CreateCallback('rm-restaurant:server:ValidateCoupon', function(source, cb, restaurantIndex, code)
    local coupon = FindActiveCoupon(restaurantIndex, code)
    if not coupon then
        cb({ valid = false })
        return
    end
    cb({ valid = true, code = coupon.code, type = coupon.type, value = coupon.value })
end)

RegisterNetEvent('rm-restaurant:server:CreateCoupon', function(restaurantIndex, data)
    local src = source
    if not CheckManagerPermission(src, restaurantIndex) then
        Notify(src, T('error.not_manager'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant then return end

    local code = (data and data.code) and tostring(data.code):upper():gsub("%s+", "") or ''
    local discountType = (data and data.type == 'fixed') and 'fixed' or 'percent'
    local value = tonumber(data and data.value) or 0

    if code == '' or value <= 0 then
        Notify(src, T('error.invalid_coupon_data'), 'error')
        return
    end

    if discountType == 'percent' then
        value = math.max(1, math.min(100, value))
    else
        value = math.max(1, value)
    end

    restaurant.coupons = restaurant.coupons or {}
    for _, c in pairs(restaurant.coupons) do
        if c.code == code then
            Notify(src, T('error.coupon_exists'), 'error')
            return
        end
    end

    local maxUses = math.max(0, tonumber(data and data.maxUses) or 0)
    local expiresInDays = tonumber(data and data.expiresInDays) or 0
    local expiresAt = expiresInDays > 0 and (os.time() + math.floor(expiresInDays * 86400)) or 0

    local insertId = MySQL.insert.await(
        'INSERT INTO rm_restaurant_coupons (restaurant_index, code, type, value, max_uses, uses, expires_at, active, created_at) VALUES (?, ?, ?, ?, ?, 0, ?, 1, ?)',
        { tonumber(restaurantIndex), code, discountType, value, maxUses, expiresAt, os.time() }
    )

    if not insertId then
        Notify(src, T('error.coupon_creation_failed'), 'error')
        return
    end

    table.insert(restaurant.coupons, 1, {
        id = insertId,
        code = code,
        type = discountType,
        value = value,
        maxUses = maxUses,
        uses = 0,
        expiresAt = expiresAt,
        active = true,
    })

    Notify(src, T('success.coupon_created', { code = code }), 'success')
    TriggerClientEvent('rm-restaurant:client:CouponsUpdated', src, tonumber(restaurantIndex), restaurant.coupons)
end)

RegisterNetEvent('rm-restaurant:server:ToggleCoupon', function(restaurantIndex, couponId, active)
    local src = source
    if not CheckManagerPermission(src, restaurantIndex) then
        Notify(src, T('error.not_manager'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant or not restaurant.coupons then return end

    for _, c in pairs(restaurant.coupons) do
        if c.id == couponId then
            c.active = active and true or false
            MySQL.update('UPDATE rm_restaurant_coupons SET active = ? WHERE id = ?', { c.active and 1 or 0, couponId })
            break
        end
    end

    TriggerClientEvent('rm-restaurant:client:CouponsUpdated', src, tonumber(restaurantIndex), restaurant.coupons)
end)

RegisterNetEvent('rm-restaurant:server:DeleteCoupon', function(restaurantIndex, couponId)
    local src = source
    if not CheckManagerPermission(src, restaurantIndex) then
        Notify(src, T('error.not_manager'), 'error')
        return
    end

    local restaurant = GetRestaurantByIndex(restaurantIndex)
    if not restaurant or not restaurant.coupons then return end

    for i, c in pairs(restaurant.coupons) do
        if c.id == couponId then
            table.remove(restaurant.coupons, i)
            break
        end
    end

    MySQL.query('DELETE FROM rm_restaurant_coupons WHERE id = ?', { couponId })
    Notify(src, T('success.coupon_deleted'), 'success')
    TriggerClientEvent('rm-restaurant:client:CouponsUpdated', src, tonumber(restaurantIndex), restaurant.coupons)
end)

-- =========================================================
--  NOTIFICAÇÃO GLOBAL (abertura/fechamento, já existente)
-- =========================================================
RegisterNetEvent('rm-restaurant:server:NotifyAllPlayers', function(data)
    local src = source

    local restaurant = select(1, GetRestaurantByName(data.restaurantName))
    if not restaurant then return end

    local _, restaurantIndex = GetRestaurantByName(data.restaurantName)
    if not CheckRestaurantPermission(src, restaurantIndex) then return end

    local statusText = data.isOpen and "ABERTO" or "FECHADO"
    local statusMessage = data.isOpen and "Está agora aberto para pedidos!" or "Foi fechado temporariamente."

    TriggerClientEvent('rm-restaurant:client:ShowRestaurantNotification', -1, {
        restaurantId = data.restaurantId,
        restaurantName = data.restaurantName,
        restaurantImage = data.restaurantImage,
        isOpen = data.isOpen,
        statusText = statusText,
        message = statusMessage,
    })
end)
