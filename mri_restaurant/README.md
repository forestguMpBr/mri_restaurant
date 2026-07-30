# 🍔 love_restaurant

Sistema completo de gerenciamento e pedidos de restaurantes para servidores **FiveM** rodando **QBox (qbx_core)** ou **QBCore (qb-core)**. Multi-restaurante, com cardápio, receitas/craft, cozinha, atendimento de balcão, totens de autoatendimento, cupons de desconto, comissão de funcionário e histórico de pedidos — tudo persistido em banco de dados via `oxmysql`.

---

## ✨ Funcionalidades

### Para o cliente
- **Tablet (F3)** com cardápio por categoria, carrinho de compras e checkout.
- Escolha entre **Entrega** (com waypoint automático) ou **Retirada no Balcão**.
- Aplicação de **cupons de desconto** (percentual ou valor fixo) no carrinho.
- **Histórico de pedidos** por personagem, com opção de "Repetir Pedido" em 1 clique.
- **Totens de autoatendimento** físicos espalhados pelo mapa (target via `ox_target`/`qb-target`/`qtarget`, com fallback nativo por tecla) para pedir sem depender de funcionário.
- Entrega automática instantânea pelo totem quando não há ninguém de plantão.

### Para o funcionário
- Painel de **Cozinha** com fila de pedidos (pendente → preparando → pronto).
- Checagem automática dos ingredientes da receita antes de preparar (craft), com aviso do que falta craftar.
- **Atendimento de Balcão**: registra pedidos presenciais, seleciona cliente próximo e envia cobrança para o jogador aceitar/recusar.
- Sistema de **comissão** configurável (% do valor da venda, direto no bolso do funcionário).
- Botão de pausar/retomar entregas quando a equipe estiver sobrecarregada.

### Para o gerente/dono
- Painel de **Gerência**: abrir/fechar o restaurante, dashboard de vendas, log de estoque.
- CRUD de itens do cardápio (preço, estoque, receita, ativar/desativar).
- CRUD de **cupons de desconto** (código, tipo, validade, limite de usos).
- Saque do caixa do restaurante para o próprio bolso.

### Arquitetura
- **Multi-restaurante**: quantos restaurantes quiser, cada um com seu próprio cardápio, caixa, funcionários, cupons e totens — tudo via `config.lua`.
- **Bridge de framework** (`bridge.lua`): detecta automaticamente `qbx_core` (Qbox) ou `qb-core` (QBCore).
- **Bridge de inventário** (`inventory_server.lua`): detecta automaticamente `ox_inventory` ou `qb-inventory`.
- **Persistência total** via `oxmysql`: cardápio, estoque, caixa, vendas, log de estoque, cupons e histórico de pedidos do cliente.
- Interface NUI construída em HTML/CSS/JS puro (sem frameworks pesados).

---

## 📋 Dependências

- [`qbx_core`](https://github.com/Qbox-project/qbx_core) **ou** `qb-core`
- [`oxmysql`](https://github.com/overextended/oxmysql)
- `ox_inventory` **ou** `qb-inventory` (detecção automática)
- `ox_target` **ou** `qb-target`/`qtarget` (opcional, usado pelos totens — há fallback nativo)

---

## 🔧 Instalação

1. Baixe/clone este resource para a pasta `resources` do seu servidor.
2. Adicione ao `server.cfg`:
   ```cfg
   ensure love_restaurant
   ```
3. As tabelas do banco de dados são criadas automaticamente na primeira inicialização (idempotente).
4. Abra `config/config.lua` e ajuste:
   - `Config.Framework` e `Config.Inventory` (deixe `'auto'` na maioria dos casos).
   - `Config.Restaurants`: nome, localização, empregos permitidos, cardápio e receitas.
   - Ajuste os `item = "..."` de cada produto/receita para os nomes reais dos itens no seu inventário.
5. Use o comando `/totempos` no jogo, de frente para o local desejado, para gerar o `vector4` exato de posicionamento de um totem e colar no `config.lua`.

---

## ⚙️ Configuração rápida

| Config | Descrição |
|---|---|
| `Config.RestaurantMenuKey` | Tecla que abre o tablet do cliente (padrão `F3`) |
| `Config.PaymentMethod` | `"cash"`, `"bank"` ou `"both"` |
| `Config.EnableTotems` | Ativa/desativa os totens de autoatendimento |
| `Config.TotemAutoDeliverWhenNoStaff` | Entrega automática pelo totem sem funcionário de plantão |
| `Config.EmployeeCommissionPercent` | % de comissão do funcionário por venda |
| `Config.EnableTabletPickupOrders` | Permite retirada pelo tablet (além do balcão) |

Veja `config/config.lua` para a lista completa, com comentários detalhados em cada opção.

---

## 📁 Estrutura

```
love_restaurant/
├── config/
│   ├── config.lua        -- configuração geral, restaurantes, cardápio
│   └── bridge.lua        -- detecção automática de framework
├── locales/
│   └── locales.lua       -- todas as mensagens/traduções (pt-BR)
├── client/
│   ├── main.lua          -- lógica principal do cliente, tablet, targets
│   └── menu.lua          -- NUI/menu
├── server/
│   ├── inventory.lua     -- bridge de inventário
│   └── main.lua          -- lógica de pedidos, cozinha, balcão, cupons, persistência
├── html/
│   ├── index.html
│   ├── app.js
│   └── style.css
└── fxmanifest.lua
```

---

## 🐛 Reportando problemas

Encontrou um bug ou tem uma sugestão? Abra uma *issue* neste repositório.

---

## 📜 Créditos

- **Dentista** — desenvolvimento e idealização do sistema
- **Claude (Anthropic)** — assistência de desenvolvimento via IA
- **rafa4l** — colaboração no desenvolvimento

---

## 📄 Licença

Este projeto está licenciado sob **[CC BY-NC 4.0](https://creativecommons.org/licenses/by-nc/4.0/deed.pt_BR)** (Atribuição-NãoComercial).

Você pode usar, modificar e redistribuir livremente — **desde que não venda** o resource (nem modificado) e **mantenha os créditos** a Dentista, Claude (Anthropic) e rafa4l. Veja o arquivo [`LICENSE`](./LICENSE) para o texto completo.
