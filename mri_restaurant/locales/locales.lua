Locale = {}

local Translations = {
    error = {
        not_authorized = 'Você não está autorizado a gerenciar este restaurante',
        already_open = 'Este restaurante já está aberto',
        already_closed = 'Este restaurante já está fechado',
        cannot_use_menu = 'Você não pode usar o menu do restaurante neste momento',
        restaurant_closed_order = 'Este restaurante está fechado no momento',
        insufficient_money = 'Você não tem dinheiro suficiente para este pedido',
        item_out_of_stock = 'Um ou mais itens do seu pedido acabaram no estoque',
        invalid_cart = 'Seu carrinho está vazio',
        order_not_found = 'Pedido não encontrado',
        not_employee = 'Você não é funcionário deste restaurante',
        not_manager = 'Você não tem permissões de gerente para este restaurante',
        withdraw_invalid = 'Valor de saque inválido',
        withdraw_insufficient_funds = 'O caixa do restaurante não tem esse valor disponível',
        order_not_ready = 'Este pedido não está no estágio correto para essa ação',
        missing_crafted_items = 'Você ainda precisa craftar: %{items}',
        customer_offline = 'O cliente não está online para receber o pedido',
        invalid_item_data = 'Preencha nome, categoria e item do inventário para criar o produto',
        item_creation_failed = 'Não foi possível criar o item do cardápio',
        invalid_coupon = 'Cupom inválido, expirado ou esgotado',
        invalid_coupon_data = 'Preencha um código e um valor de desconto válidos',
        coupon_exists = 'Já existe um cupom com este código',
        coupon_creation_failed = 'Não foi possível criar o cupom',
        invalid_order_type = 'Selecione se o pedido é para retirada ou entrega',
        delivery_needs_two_employees = 'É necessário pelo menos 2 funcionários de plantão para entregas. Seu pedido foi enviado como retirada no balcão.',
        pickup_disabled_use_counter = 'Retirada pelo tablet está desabilitada. Faça seu pedido diretamente no balcão com um funcionário.',
        totem_auto_deliver_failed = 'Não foi possível entregar o pedido automaticamente (verifique o espaço no seu inventário). Você não foi cobrado.',
        totem_staff_online = 'Há funcionário(s) de plantão agora! Faça seu pedido diretamente no balcão com um deles.',
        delivery_paused_by_staff = 'A equipe pausou as entregas no momento. Seu pedido foi enviado como retirada no balcão.',
        customer_too_far = 'O cliente selecionado está longe demais. Peça pra ele chegar mais perto do balcão.',
        customer_insufficient_money = 'O cliente selecionado não tem dinheiro suficiente para este pedido.',
        no_customer_selected = 'Selecione um cliente próximo antes de registrar o pedido',
        charge_declined_by_customer = 'O cliente recusou a cobrança. O pedido do balcão foi cancelado.',
        charge_request_timeout = 'O cliente não respondeu à cobrança a tempo. O pedido do balcão foi cancelado.',
        charge_request_invalid = 'Esta cobrança não é mais válida.',
    },
    success = {
        restaurant_opened = 'Você abriu com sucesso o %{restaurant}',
        restaurant_closed = 'Você fechou com sucesso o %{restaurant}',
        waypoint_set = 'GPS configurado para %{restaurant}',
        order_placed = 'Pedido enviado! Aguarde a preparação.',
        order_accepted = 'Pedido #%{id} aceito',
        order_ready = 'Seu pedido em %{restaurant} está pronto para retirada!',
        order_delivered = 'Pedido #%{id} entregue ao cliente',
        stock_updated = 'Estoque atualizado com sucesso',
        item_updated = 'Item do cardápio atualizado',
        withdraw_success = 'Você sacou %{amount} do caixa do restaurante',
        item_created = 'Item "%{item}" criado no cardápio com sucesso',
        commission_received = 'Você recebeu R$ %{amount} de comissão pela venda #%{id}',
        coupon_created = 'Cupom "%{code}" criado com sucesso',
        coupon_deleted = 'Cupom removido com sucesso',
        coupon_applied = 'Cupom "%{code}" aplicado com sucesso',
        counter_order_registered = 'Pedido #%{id} registrado! Total: R$ %{total} - informe o valor ao cliente.',
        totem_auto_delivered = 'Nenhum funcionário de plantão no momento! Seu pedido foi preparado e entregue automaticamente.',
        delivery_paused = 'Entregas pausadas. Os pedidos agora só vão sair como retirada no balcão.',
        delivery_resumed = 'Entregas retomadas. Os clientes já podem escolher entrega novamente.',
        charge_request_sent = 'Cobrança enviada ao cliente. Aguardando confirmação...',
    },
    info = {
        open_restaurant = 'Abrir Restaurante',
        close_restaurant = 'Fechar Restaurante',
        restaurant_status = 'Status: %{status}',
        restaurant_menu = 'Gerenciamento de Restaurante',
        restaurant_open = 'ABERTO',
        restaurant_closed = 'FECHADO',
        notification_open = '%{restaurant} agora está ABERTO!',
        notification_closed = '%{restaurant} agora está FECHADO!',
        set_gps = 'Definir GPS',
        new_order = 'Novo pedido recebido em %{restaurant}!',
        new_order_totem = 'Novo pedido recebido via TOTEM em %{restaurant}!',
        new_order_counter = 'Novo pedido registrado no BALCÃO em %{restaurant}!',
        delivery_waypoint_set = 'GPS atualizado com o destino da entrega do pedido #%{id}',
        order_type_pickup = 'Retirada no Balcão',
        order_type_delivery = 'Entrega',
        counter_charged = 'Você foi cobrado R$ %{amount} no %{restaurant} (pedido no balcão)',
        charge_prompt = 'Você está sendo cobrado por %{restaurant}: R$ %{amount}',
        charge_prompt_hint = '[E] Aceitar        [BACKSPACE] Recusar',
        customer_declined_charge = 'Você recusou a cobrança.',
        customer_charge_timeout = 'Você não respondeu a tempo. A cobrança foi cancelada.',
    },
    menu = {
        open_menu = 'Abrir Menu',
        restaurant_list = 'Lista de Restaurantes',
        manage_restaurant = 'Gerenciar Restaurante',
        tab_home = 'Início',
        tab_orders = 'Pedidos',
        tab_manage = 'Gerenciar',
        tab_history = 'Histórico',
        cart = 'Carrinho',
        checkout = 'Finalizar Pedido',
        total = 'Total',
        pending = 'Pendente',
        preparing = 'Preparando',
        ready = 'Pronto',
        completed = 'Concluído',
        coupons = 'Cupons de Desconto',
        new_coupon = 'Novo Cupom',
        order_type_question = 'Como você quer receber seu pedido?',
        order_history = 'Histórico de Pedidos',
        order_history_empty = 'Você ainda não fez nenhum pedido',
        repeat_order = 'Repetir Pedido',
        repeat_order_unavailable = 'Nenhum item deste pedido está disponível no momento',
        repeat_order_partial = 'Alguns itens desse pedido não puderam ser adicionados (esgotados ou indisponíveis)',
    },
}

function Locale.new(_, opts)
    local self = {}

    self.phrases = opts.phrases or Translations
    self.warnOnMissing = opts.warnOnMissing
    self.fallbackLang = opts.fallbackLang or self

    self.t = function(_, phrase, vars)
        if not phrase then return '' end

        vars = vars or {}

        local split = {}
        for str in string.gmatch(phrase, "([^.]+)") do
            split[#split + 1] = str
        end

        local result = self.phrases

        for i = 1, #split do
            local key = split[i]
            result = result[key]
            if not result then
                if self.warnOnMissing then
                    print(("Translation for %s does not exist"):format(phrase))
                end
                return phrase
            end
        end

        if type(result) ~= 'string' then
            if self.warnOnMissing then
                print(("Translation for %s is not a string"):format(phrase))
            end
            return phrase
        end

        for k, v in pairs(vars) do
            result = result:gsub('%%{' .. k .. '}', tostring(v))
        end

        return result
    end

    return self
end

Lang = Locale.new(nil, {
    phrases = Translations,
    warnOnMissing = true
})
