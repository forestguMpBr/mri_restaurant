Config = {}

-- =========================================================
--  FRAMEWORK
--  Funciona com qbx_core (Qbox) e qb-core (QBCore) automaticamente.
--  Se seu servidor usa Qbox com outro nome de export, ajuste aqui.
-- =========================================================
Config.Framework = 'auto' -- 'auto' | 'qbx_core' | 'qb-core'

-- Sistema de inventário usado para checar/remover itens craftados pelo funcionário
-- na hora da entrega, e para dar o item ao cliente.
Config.Inventory = 'auto' -- 'auto' | 'ox_inventory' | 'qb-inventory'

-- =========================================================
--  RESTAURANTES
--  Cada item do "menu" vira um pedido que o funcionário recebe no tablet.
--  "stock" controla quantas unidades existem disponíveis pra venda.
--  Ajuste "item" para o nome do item real no seu inventário (ox_inventory / qb-inventory).
-- =========================================================
Config.Restaurants = {
    {
        name = "Burger Shot",
        label = "Burger Shot",
        location = vec3(-1175.29, -877.09, 14.05),
        blip = { sprite = 106, color = 1, scale = 0.7 },
        logo = "img/burgershot-logo.png",
        banner = "img/burgershot-banner.jpg",
        isOpen = false,
        allowedJobs = { "burgershot" },
        managerGrades = { 3, 4 }, -- graus do emprego com acesso ao painel de gerência
        balance = 0, -- caixa do restaurante (saque pelo gerente)
        -- Totens de autoatendimento deste restaurante (opcional, veja Config.EnableTotems
        -- mais abaixo). Ajuste a posição/rotação exatas com o comando /totempos.
        --
        -- Cada item aceita 2 formatos:
        --   1) vector4(x, y, z, heading)  -> formato antigo, sempre SPAWNA o
        --      prop configurado em Config.TotemModel naquela posição.
        --   2) { coords = vector4(x, y, z, heading), useProp = false }
        --      -> NÃO spawna prop nenhum, só cria a zona de interação (target)
        --      naquela coordenada. Use isso quando o totem já existe fisicamente
        --      no mapa (YMAP, MLO, prop de outro resource) e você só precisa
        --      do "olhinho"/target ali, sem duplicar o objeto.
        --      Também aceita "model = 'outro_prop'" pra spawnar um prop
        --      diferente do padrão só nesse totem específico (útil se algum
        --      restaurante tiver um totem visualmente diferente).
        totems = {
            { coords = vector4(-1183.15, -884.79, 14.38, 311.92), useProp = false },
            -- Exemplo de totem sem prop, só com a zona de interação:
            -- { coords = vector4(-1180.10, -880.20, 14.38, 120.0), useProp = false },
        },
        menu = {
            {
                id = 1, category = "lanches", name = "X-Burger",
                description = "Pão, carne, queijo, alface e tomate",
                price = 25, item = "burger", image = "img/items/xburger.png",
                enabled = true, stock = 50, prepTime = 20,
                -- "item" = nome do item real no seu inventário (ajuste pro que você usa).
                -- "qty" = quantidade por unidade do pedido (multiplicada pela qtd pedida).
                -- "item = false" = passo sem checagem de inventário (só instrução).
                recipe = {
                    { item = "rm_pao_brioche", label = "Pão de Brioche (com gergelim)", qty = 1 },
                    { item = "rm_frango_bife", label = "Hambúrguer de Frango (160g)", qty = 1 },
                    { item = "rm_queijo_prato", label = "Queijo Prato (fatia)", qty = 2 },
                    { item = "rm_maionese", label = "Maionese Especial", qty = 1 },
                    { item = "rm_alface_tomate", label = "Alface e Tomate", qty = 1 },
                },
            },
            {
                id = 2, category = "lanches", name = "Cheeseburger Duplo",
                description = "Dois hambúrgueres e queijo cheddar",
                price = 38, item = "rm_double_cheese", image = "img/items/double_cheese.png",
                enabled = true, stock = 40, prepTime = 25,
                recipe = {
                    { item = "rm_pao_brioche", label = "Pão de Brioche (com gergelim)", qty = 1 },
                    { item = "rm_carne_bovina", label = "Hambúrguer Bovino (160g)", qty = 2 },
                    { item = "rm_queijo_cheddar", label = "Queijo Cheddar (fatia)", qty = 2 },
                    { item = "rm_molho_especial", label = "Molho Especial", qty = 1 },
                    { item = "rm_cebola_caramelizada", label = "Cebola Caramelizada", qty = 1 },
                },
            },
            {
                id = 3, category = "acompanhamentos", name = "Batata Frita",
                description = "Porção individual de batatas fritas",
                price = 12, item = "rm_fries", image = "img/items/fries.png",
                enabled = true, stock = 60, prepTime = 15,
                recipe = {
                    { item = "rm_batata_congelada", label = "Batata Palito Congelada", qty = 1 },
                    { item = "rm_sal_temperado", label = "Sal Temperado", qty = 1 },
                    { item = false, label = "1 fritada no óleo quente (3 min)" },
                },
            },
            {
                id = 4, category = "bebidas", name = "Coca-Cola",
                description = "Refrigerante gelado 500ml",
                price = 8, item = "cola", image = "img/items/cola.png",
                enabled = true, stock = 80, prepTime = 5,
                recipe = {
                    { item = "rm_lata_cola", label = "Lata/Garrafa Coca-Cola gelada", qty = 1 },
                    { item = "rm_gelo", label = "Gelo (copo)", qty = 1 },
                },
            },
            {
                id = 5, category = "bebidas", name = "Suco de Laranja",
                description = "Suco natural de laranja",
                price = 10, item = "sprunk", image = "img/items/orange_juice.png",
                enabled = true, stock = 50, prepTime = 5,
                recipe = {
                    { item = "rm_laranja", label = "Laranjas frescas", qty = 3 },
                    { item = "rm_gelo", label = "Gelo (porção)", qty = 1 },
                    { item = false, label = "1 copo para servir" },
                },
            },
        },
    },
    {
        name = "uWu Cafe",
        label = "uWu Cafe",
        location = vec3(-580.78, -1072.83, 22.33),
        blip = { sprite = 267, color = 19, scale = 0.7 },
        logo = "img/uwucafe-logo.png",
        banner = "img/uwucafe-banner.jpg",
        isOpen = false,
        allowedJobs = { "uwucafe" },
        managerGrades = { 3, 4 },
        balance = 0,
        totems = {
            vector4(-580.78, -1075.60, 22.33, 30.0),
        },
        menu = {
            {
                id = 1, category = "bebidas_quentes", name = "Café Expresso",
                description = "Café puro e encorpado",
                price = 9, item = "rm_espresso", image = "img/items/espresso.png",
                enabled = true, stock = 60, prepTime = 10,
                recipe = {
                    { item = "rm_cafe_moido", label = "Café Moído (dose)", qty = 1 },
                    { item = false, label = "Extração na máquina (30s)" },
                },
            },
            {
                id = 2, category = "bebidas_quentes", name = "Cappuccino",
                description = "Café com espuma de leite e canela",
                price = 14, item = "rm_cappuccino", image = "img/items/cappuccino.png",
                enabled = true, stock = 45, prepTime = 15,
                recipe = {
                    { item = "rm_cafe_moido", label = "Café Moído (dose)", qty = 1 },
                    { item = "rm_leite", label = "Leite Vaporizado (porção)", qty = 1 },
                    { item = "rm_canela", label = "Canela (pitada)", qty = 1 },
                },
            },
            {
                id = 3, category = "doces", name = "Fatia de Bolo",
                description = "Bolo de chocolate caseiro",
                price = 16, item = "rm_cake_slice", image = "img/items/cake_slice.png",
                enabled = true, stock = 30, prepTime = 10,
                recipe = {
                    { item = "rm_bolo_chocolate", label = "Fatia de Bolo de Chocolate", qty = 1 },
                    { item = "rm_calda_chocolate", label = "Calda de Chocolate (porção)", qty = 1 },
                },
            },
            {
                id = 4, category = "bebidas_frias", name = "Chá Gelado",
                description = "Chá gelado de pêssego",
                price = 11, item = "rm_iced_tea", image = "img/items/iced_tea.png",
                enabled = true, stock = 40, prepTime = 8,
                recipe = {
                    { item = "rm_cha_pessego", label = "Chá de Pêssego concentrado (dose)", qty = 1 },
                    { item = "rm_gelo", label = "Gelo (porção)", qty = 1 },
                },
            },
        },
    },
}

-- =========================================================
--  TABLET (usado por clientes, funcionários e gerentes)
-- =========================================================
Config.TabletModel = "prop_cs_tablet"
Config.TabletAnimDict = "amb@code_human_in_bus_passenger_idles@female@tablet@base"
Config.TabletAnim = "base"
Config.TabletBone = 60309
Config.TabletOffset = vector3(0.03, 0.002, -0.0)
Config.TabletRot = vector3(10.0, 160.0, 0.0)

-- Tecla para abrir o tablet de restaurantes
Config.RestaurantMenuKey = 'F3'

-- Distância máxima (metros) para retirar um pedido pronto no balcão do restaurante
Config.PickupRadius = 15.0

-- Forma de pagamento aceita no pedido: "cash", "bank" ou "both"
Config.PaymentMethod = "both"

-- Distância máxima (metros) pra selecionar um cliente próximo no Atendimento
-- (balcão) e pra revalidar no servidor na hora de cobrar. O funcionário só
-- consegue selecionar/cobrar quem estiver fisicamente perto dele.
Config.CounterCustomerMaxDistance = 5.0

-- Permite retirada ("pickup") como opção de pedido feito pelo TABLET (F3)
-- pelo próprio cliente. Com o Atendimento de Balcão (funcionário registra o
-- pedido presencialmente), retirada pelo tablet fica redundante - então por
-- padrão aqui está DESABILITADA, sobrando só "Entregar" na tela de checkout.
-- Não afeta o Totem de autoatendimento (Config.EnableTotems), que continua
-- oferecendo as duas opções normalmente.
Config.EnableTabletPickupOrders = false

-- =========================================================
--  TOTENS DE AUTOATENDIMENTO (opcional)
--  Terminais físicos espalhados pelo restaurante (balcão, entrada, etc)
--  que QUALQUER cliente pode usar - com o "olhinho"/target - pra ver o
--  cardápio e fazer o pedido sozinho, sem depender de um funcionário
--  livre pra atender. O pedido chega na cozinha marcado como "via Totem".
--
--  Detecta automaticamente ox_target ou qb-target/qtarget; se nenhum dos
--  dois estiver rodando, cai num fallback nativo (tecla E por perto, sem
--  dependências externas), igual ao resto do resource faz com framework
--  e inventário.
--
--  Cada restaurante tem sua própria lista `totems` (veja acima, em
--  Config.Restaurants) com vector4(x, y, z, heading). Pra achar a posição
--  exata onde quiser colocar o totem, fique de frente pro local e use o
--  comando /totempos - ele imprime no chat/console o vector4 prontinho
--  pra colar no config.
-- =========================================================
Config.EnableTotems = true
Config.TotemModel = 'prop_x17_screen_01a' -- troque pelo prop/MLO de totem que preferir
Config.TotemInteractDistance = 1.5
Config.TotemTargetIcon = 'fas fa-concierge-bell'
Config.TotemTargetLabel = 'Fazer Pedido (Totem)'

-- Se TRUE: quando um pedido for feito pelo TOTEM e não houver nenhum
-- funcionário de plantão naquele restaurante no momento, o pedido pula a
-- cozinha inteira e o item é entregue automaticamente e instantaneamente
-- no inventário do cliente (tipo uma máquina de autoatendimento de
-- verdade). Não gera comissão pra ninguém (não tem funcionário pra
-- receber), só credita o valor no caixa do restaurante normalmente.
-- Se FALSE, o pedido do totem sempre vai pra cozinha normalmente, mesmo
-- sem ninguém de plantão pra prepará-lo.
Config.TotemAutoDeliverWhenNoStaff = true

-- =========================================================
--  COMISSÃO DO FUNCIONÁRIO
--  Quando o funcionário confirma a entrega do pedido, essa
--  porcentagem do valor da venda vai direto pro bolso dele
--  (dinheiro). O restante fica no caixa do restaurante,
--  disponível para o dono/gerente sacar depois.
-- =========================================================
Config.EmployeeCommissionPercent = 40 -- 0 a 100
Config.EmployeeCommissionMoneyType = "cash" -- "cash" ou "bank"

-- Notificações
Config.NotificationDuration = 8000 -- ms
