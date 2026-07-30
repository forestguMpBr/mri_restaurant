# Totem de Autoatendimento — o que foi feito

## O que os scripts de referência fazem (pesquisa rápida)
Os scripts de restaurante mais bem avaliados pra FiveM hoje (ex: "Best Restaurant System - Self ordering Tablets", VC-Restaurants, mato-multirestaurant, Advanced Menucards) convergem num padrão parecido:
- Um prop físico (totem/tablet fixo) espalhado pelo mapa, ativado via **ox_target** (ou qb-target/qtarget como alternativa).
- Qualquer cliente pode usar - não precisa ser funcionário.
- O pedido cai direto na cozinha e os funcionários recebem notificação em tempo real, geralmente com uma marcação indicando que veio do totem (pra diferenciar de quem pediu pelo tablet/pessoalmente).

Foi exatamente esse padrão que integrei no seu script, reaproveitando 100% do fluxo de pedido/cardápio/carrinho que você já tinha - só mudou **de onde** o pedido é feito.

## Como funciona agora
1. **Totens físicos por restaurante** (`config.lua`): cada restaurante tem uma lista `totems = { vector4(x, y, z, heading), ... }`. Já deixei uma posição de exemplo pra Burger Shot e uWu Cafe - ajuste com o comando `/totempos` (fique de frente pro lugar desejado e rode o comando; ele imprime o `vector4` pronto pra colar no config).
2. **Detecção automática de target** (`client.lua`): usa `ox_target` se estiver rodando, senão `qb-target`/`qtarget`, e se nenhum dos dois existir cai num fallback nativo (tecla **E** com texto 3D) - sem exigir nenhuma dependência nova, do mesmo jeito que o resto do script já detecta framework/inventário automaticamente.
3. **Abrir o totem** (`menu.lua` → `OpenTotemOrderMenu`): mostra só o cardápio + carrinho daquele restaurante específico (sem lista de restaurantes, sem abas de funcionário/gerência) - qualquer cliente pode usar, mesmo sem ser funcionário.
4. **Origem do pedido** (`server.lua` / `app.js`): todo pedido agora carrega `orderSource: 'tablet' | 'totem'`. Quando vem do totem:
   - A notificação dos funcionários muda pra "Novo pedido recebido via TOTEM em [restaurante]!".
   - O card do pedido na Cozinha ganha um selo roxo **"Totem"** ao lado do selo de Retirada/Entrega, então dá pra saber de cara que ninguém "pegou o pedido" fisicamente com o cliente.

## Não precisou mexer no fxmanifest
Toda a lógica nova foi colocada dentro dos arquivos que você já tinha (`config.lua`, `client.lua`, `menu.lua`, `server.lua`, `locales.lua`, `app.js`, `style.css`) - nenhum arquivo novo foi criado, então não precisa adicionar nada no `fxmanifest.lua`.

## O que ajustar antes de usar
- **`Config.TotemModel`** (`config.lua`): coloquei `prop_atm_01` como placeholder só pra ter algo funcional de cara. Troque pelo prop/MLO de totem que preferir (ex: um terminal de autoatendimento realista).
- **Posições dos totens**: use `/totempos` em cada restaurante pra pegar as coordenadas certas do balcão/entrada e cole em `totems = { ... }`.
- **`Config.EnableTotems = false`** desativa a spawnagem dos totens em todos os restaurantes, se quiser desligar a feature sem remover nada.

## Arquivos alterados
`config.lua`, `client.lua`, `menu.lua`, `server.lua`, `locales.lua`, `app.js`, `style.css`.
Não mexi em `index.html`, `inventory.lua` e `bridge.lua` - não precisaram de nenhuma mudança.
