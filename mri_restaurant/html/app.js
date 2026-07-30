// =============================================================
//  RESTAURANT MANAGER PRO - app.js
//  Cliente / Funcionário (cozinha) / Gerente, tudo num só tablet
// =============================================================

const isBrowserPreview = !window.invokeNative;

function nuiFetch(eventName, data = {}) {
  return fetch(`https://${getResourceName()}/${eventName}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data),
  })
    .then((res) => res.json())
    .catch(() => null);
}

function getResourceName() {
  return typeof GetParentResourceName === "function" ? GetParentResourceName() : "love_restaurant";
}

// -------------------------------------------------------------
//  ESTADO GLOBAL
// -------------------------------------------------------------
const state = {
  restaurants: [],
  job: null,
  grade: null,
  onDuty: false,
  employeeRestaurantIndex: null,
  myServerId: null,
  currentPage: "home",
  currentRestaurant: null, // objeto de menu carregado (getMenu)
  cart: {}, // { itemId: {..item, qty} }
  kitchenOrders: { pending: [], preparing: [], ready: [] },
  manageData: null,
  manageSubpage: "catalog",
  stockData: null,
  salesLog: [],
  dashboardStats: [],
  manageStockLog: [],
  coupons: [],
  appliedCoupon: null, // { code, type, value } - aplicado no carrinho atual
  totemMode: false, // true quando o menu foi aberto por um totem de autoatendimento
  counterRestaurant: null, // cardápio carregado pra aba Atendimento (getMenu do próprio restaurante do funcionário)
  counterCart: {}, // { itemId: {..item, qty} } - carrinho separado do carrinho do cliente
  counterAppliedCoupon: null, // { code, type, value } - cupom aplicado pelo funcionário no pedido de balcão
  counterCustomer: null, // { serverId, name } - cliente próximo selecionado pra enviar a solicitação de cobrança no balcão
  enablePickupOrders: true, // controlado por Config.EnableTabletPickupOrders (só afeta pedido via tablet, não totem)
  orderHistory: [], // últimos pedidos do próprio jogador (aba "Histórico"), usado pra repetir pedido
};

// -------------------------------------------------------------
//  MOCK DATA (apenas para pré-visualização no navegador)
// -------------------------------------------------------------
const MOCK_RESTAURANTS = [
  { id: 1, name: "Burger Shot", label: "Burger Shot", logo: "img/burgershot-logo.png", banner: "img/burgershot-banner.jpg", status: true, isEmployee: true, isManager: true },
  { id: 2, name: "uWu Cafe", label: "uWu Cafe", logo: "img/uwucafe-logo.png", banner: "img/uwucafe-banner.jpg", status: false, isEmployee: false, isManager: false },
];

const MOCK_MENU = {
  1: {
    name: "Burger Shot", label: "Burger Shot", isOpen: true,
    menu: [
      { id: 1, category: "lanches", name: "X-Burger", description: "Pão, carne, queijo, alface e tomate", price: 25, image: "img/items/xburger.png", enabled: true, stock: 50 },
      { id: 2, category: "lanches", name: "Cheeseburger Duplo", description: "Dois hambúrgueres e queijo cheddar", price: 38, image: "img/items/double_cheese.png", enabled: true, stock: 40 },
      { id: 3, category: "acompanhamentos", name: "Batata Frita", description: "Porção individual de batatas fritas", price: 12, image: "img/items/fries.png", enabled: true, stock: 60 },
      { id: 4, category: "bebidas", name: "Coca-Cola", description: "Refrigerante gelado 500ml", price: 8, image: "img/items/cola.png", enabled: true, stock: 80 },
    ],
  },
};

// -------------------------------------------------------------
//  UTIL
// -------------------------------------------------------------
function formatMoney(v) {
  return "R$ " + Number(v || 0).toLocaleString("pt-BR", { minimumFractionDigits: 2 });
}

function showToast(message, type = "info") {
  const container = document.getElementById("toast-container");
  const toast = document.createElement("div");
  toast.className = `toast toast-${type}`;
  toast.innerHTML = `<i class="fas ${type === "success" ? "fa-circle-check" : type === "error" ? "fa-circle-exclamation" : "fa-bell"}"></i><span>${message}</span>`;
  container.appendChild(toast);
  requestAnimationFrame(() => toast.classList.add("show"));
  setTimeout(() => {
    toast.classList.remove("show");
    setTimeout(() => toast.remove(), 300);
  }, 4500);
}

function setPage(page) {
  state.currentPage = page;
  document.querySelectorAll(".page").forEach((el) => (el.style.display = "none"));
  document.getElementById(`page-${page}`).style.display = "block";

  document.querySelectorAll(".nav-btn[data-page]").forEach((btn) => {
    btn.classList.toggle("active", btn.dataset.page === page);
  });

  const backBtn = document.getElementById("back-btn");
  backBtn.style.display = page === "home" ? "none" : "flex";

  const titles = {
    home: ["Estabelecimentos", "Os melhores restaurantes da cidade"],
    catalog: [
      state.currentRestaurant ? state.currentRestaurant.label : "Cardápio",
      state.totemMode ? "Totem de Autoatendimento" : "Faça seu pedido",
    ],
    history: ["Histórico de Pedidos", "Seus últimos pedidos - repita com 1 clique"],
    kitchen: ["Cozinha", "Pedidos em tempo real"],
    counter: ["Atendimento", "Registre pedidos feitos no balcão"],
    stock: ["Estoque", "Abasteça com os itens que você craftou"],
    manage: ["Gerenciar Restaurante", "Cardápio, vendas e caixa"],
  };
  document.getElementById("header-title").textContent = titles[page][0];
  document.getElementById("header-subtitle").textContent = titles[page][1];

  updateCartPill();
}

// -------------------------------------------------------------
//  RELÓGIO
// -------------------------------------------------------------
function updateClock() {
  const now = new Date();
  document.getElementById("current-time").textContent =
    now.getHours().toString().padStart(2, "0") + ":" + now.getMinutes().toString().padStart(2, "0");
}
setInterval(updateClock, 30000);
updateClock();

// =============================================================
//  PÁGINA: HOME (lista de restaurantes)
// =============================================================
function renderHome() {
  const container = document.getElementById("restaurants-container");
  const activeSection = document.getElementById("active-restaurant");
  container.innerHTML = "";
  activeSection.innerHTML = "";

  const cardTemplate = document.getElementById("restaurant-card-template");
  const activeTemplate = document.getElementById("active-restaurant-template");

  let anyManagerOrEmployee = false;

  state.restaurants.forEach((restaurant) => {
    if (restaurant.isEmployee) {
      anyManagerOrEmployee = true;
      const node = activeTemplate.content.cloneNode(true);
      node.querySelector(".restaurant-bg-img").src = restaurant.banner || "img/placeholder-banner.jpg";
      node.querySelector(".restaurant-logo").src = restaurant.logo || "img/placeholder-logo.png";
      node.querySelector(".restaurant-title").textContent = restaurant.label;
      node.querySelector(".status-text").textContent = restaurant.status ? "ABERTO" : "FECHADO";
      node.querySelector(".status-light").classList.add(restaurant.status ? "on" : "off");

      node.querySelector(".location-btn").addEventListener("click", () => setWaypoint(restaurant));

      const manageBtn = node.querySelector(".manage-btn");
      if (restaurant.isManager) {
        manageBtn.addEventListener("click", () => openManage(restaurant.id));
      } else {
        manageBtn.style.display = "none";
      }

      const toggleBtn = node.querySelector(".toggle-btn");
      toggleBtn.addEventListener("click", () => toggleRestaurant(restaurant));

      activeSection.appendChild(node);
    }
  });

  state.restaurants.forEach((restaurant) => {
    const node = cardTemplate.content.cloneNode(true);
    const card = node.querySelector(".restaurant-card");
    card.addEventListener("click", (e) => {
      if (e.target.closest(".location-btn")) return;
      openCatalog(restaurant.id);
    });

    node.querySelector(".thumb-img").src = restaurant.logo || "img/placeholder-logo.png";
    node.querySelector(".status-dot").classList.add(restaurant.status ? "on" : "off");
    node.querySelector(".restaurant-name").textContent = restaurant.label;
    const statusText = node.querySelector(".card-status-text");
    statusText.textContent = restaurant.status ? "Aberto agora" : "Fechado";
    statusText.classList.add(restaurant.status ? "open" : "closed");

    node.querySelector(".location-btn").addEventListener("click", (e) => {
      e.stopPropagation();
      setWaypoint(restaurant);
    });

    container.appendChild(node);
  });

  document.getElementById("nav-kitchen").style.display = anyManagerOrEmployee ? "flex" : "none";
  document.getElementById("nav-counter").style.display = anyManagerOrEmployee ? "flex" : "none";
  document.getElementById("nav-stock").style.display = anyManagerOrEmployee ? "flex" : "none";
  document.getElementById("nav-manage").style.display = state.restaurants.some((r) => r.isManager) ? "flex" : "none";
}

function setWaypoint(restaurant) {
  nuiFetch("setWaypoint", { id: restaurant.id, name: restaurant.label });
}

function toggleRestaurant(restaurant) {
  nuiFetch("toggleRestaurant", { id: restaurant.id, state: !restaurant.status }).then(() => {
    restaurant.status = !restaurant.status;
    renderHome();
  });
}

// =============================================================
//  PÁGINA: CARDÁPIO (cliente faz o pedido)
// =============================================================
function openCatalog(restaurantId, onLoaded) {
  const endpoint = state.totemMode ? "getTotemMenu" : "getMenu";
  const req = isBrowserPreview ? Promise.resolve(MOCK_MENU[restaurantId]) : nuiFetch(endpoint, { id: restaurantId });

  req.then((data) => {
    if (!data) {
      if (state.totemMode) {
        showToast("Um funcionário entrou de plantão - use o balcão pra continuar", "error");
        closeApp();
      } else {
        showToast("Não foi possível carregar o cardápio", "error");
      }
      return;
    }
    data.id = restaurantId;
    state.currentRestaurant = data;
    state.cart = {};
    state.appliedCoupon = null;
    renderCatalog();
    setPage("catalog");
    if (typeof onLoaded === "function") onLoaded(data);
  });
}

function renderCatalog() {
  const restaurant = state.currentRestaurant;
  const banner = document.getElementById("catalog-banner");
  const restaurantMeta = state.restaurants.find((r) => r.id === restaurant.id) || {};
  banner.style.backgroundImage = `url('${restaurantMeta.banner || "img/placeholder-banner.jpg"}')`;

  const statusEl = document.getElementById("catalog-status");
  statusEl.innerHTML = `<span class="status-dot ${restaurant.isOpen ? "on" : "off"}"></span> ${
    restaurant.isOpen ? "Restaurante aberto - pedidos disponíveis" : "Restaurante fechado no momento"
  }`;

  const categories = [...new Set(restaurant.menu.map((i) => i.category))];
  const tabsEl = document.getElementById("category-tabs");
  tabsEl.innerHTML = "";
  categories.forEach((cat, idx) => {
    const btn = document.createElement("button");
    btn.className = "filter-btn" + (idx === 0 ? " active" : "");
    btn.textContent = formatCategory(cat);
    btn.dataset.category = cat;
    btn.addEventListener("click", () => {
      tabsEl.querySelectorAll(".filter-btn").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      renderMenuGrid(cat);
    });
    tabsEl.appendChild(btn);
  });

  renderMenuGrid(categories[0]);
}

function formatCategory(cat) {
  return cat
    .replace(/_/g, " ")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function renderMenuGrid(category) {
  const grid = document.getElementById("menu-grid");
  grid.innerHTML = "";
  const template = document.getElementById("menu-item-template");
  const restaurant = state.currentRestaurant;

  restaurant.menu
    .filter((item) => item.category === category)
    .forEach((item) => {
      const node = template.content.cloneNode(true);
      const card = node.querySelector(".menu-item-card");
      node.querySelector(".menu-item-img img").src = item.image || "img/placeholder-item.png";
      node.querySelector(".menu-item-name").textContent = item.name;
      node.querySelector(".menu-item-desc").textContent = item.description || "";
      node.querySelector(".menu-item-price").textContent = formatMoney(item.price);

      const qtyValue = node.querySelector(".qty-value");
      let qty = 1;
      node.querySelector(".qty-btn.minus").addEventListener("click", () => {
        qty = Math.max(1, qty - 1);
        qtyValue.textContent = qty;
      });
      node.querySelector(".qty-btn.plus").addEventListener("click", () => {
        qty = Math.min(item.stock, qty + 1);
        qtyValue.textContent = qty;
      });

      const addBtn = node.querySelector(".add-btn");
      if (!item.enabled || item.stock <= 0 || !restaurant.isOpen) {
        addBtn.disabled = true;
        addBtn.innerHTML = `<i class="fas fa-ban"></i> Indisponível`;
        card.classList.add("disabled");
      } else {
        addBtn.addEventListener("click", () => addToCart(item, qty));
      }

      grid.appendChild(node);
    });
}

// -------------------------------------------------------------
//  CARRINHO
// -------------------------------------------------------------
function addToCart(item, qty, silent = false) {
  if (!state.cart[item.id]) {
    state.cart[item.id] = { ...item, qty: 0 };
  }
  state.cart[item.id].qty += qty;
  updateCartPill();
  renderCart();
  if (!silent) showToast(`${item.name} adicionado ao carrinho`, "success");
}

function updateCartPill() {
  const totalItems = Object.values(state.cart).reduce((sum, i) => sum + i.qty, 0);
  const pill = document.getElementById("cart-pill");
  document.getElementById("cart-count").textContent = totalItems;
  pill.style.display = state.currentPage === "catalog" && totalItems > 0 ? "flex" : "none";
}

function renderCart() {
  const container = document.getElementById("cart-items");
  container.innerHTML = "";
  const template = document.getElementById("cart-item-template");
  let subtotal = 0;

  Object.values(state.cart).forEach((item) => {
    if (item.qty <= 0) return;
    subtotal += item.qty * item.price;
    const node = template.content.cloneNode(true);
    node.querySelector(".cart-item-name").textContent = item.name;
    node.querySelector(".cart-item-price").textContent = formatMoney(item.price * item.qty);
    const qtyValue = node.querySelector(".qty-value");
    qtyValue.textContent = item.qty;

    node.querySelector(".qty-btn.minus").addEventListener("click", () => {
      item.qty -= 1;
      if (item.qty <= 0) delete state.cart[item.id];
      updateCartPill();
      renderCart();
    });
    node.querySelector(".qty-btn.plus").addEventListener("click", () => {
      item.qty += 1;
      updateCartPill();
      renderCart();
    });

    container.appendChild(node);
  });

  const discount = calcCouponDiscount(subtotal);
  const total = Math.max(0, subtotal - discount);

  const discountRow = document.getElementById("cart-discount-row");
  if (discount > 0) {
    discountRow.style.display = "flex";
    document.getElementById("cart-discount").textContent = "- " + formatMoney(discount);
  } else {
    discountRow.style.display = "none";
  }

  document.getElementById("cart-total").textContent = formatMoney(total);
  renderAppliedCoupon();

  if (Object.keys(state.cart).length === 0) {
    container.innerHTML = `<p class="empty-state">Seu carrinho está vazio</p>`;
  }
}

// -------------------------------------------------------------
//  CUPOM DE DESCONTO NO CARRINHO
// -------------------------------------------------------------
function calcCouponDiscount(subtotal, coupon = state.appliedCoupon) {
  if (!coupon || subtotal <= 0) return 0;
  if (coupon.type === "fixed") return Math.min(subtotal, coupon.value);
  return Math.floor(subtotal * (coupon.value / 100));
}

function renderAppliedCoupon() {
  const row = document.getElementById("cart-coupon-row");
  const applied = document.getElementById("cart-coupon-applied");
  const coupon = state.appliedCoupon;

  if (coupon) {
    row.style.display = "none";
    applied.style.display = "flex";
    const desc = coupon.type === "fixed" ? formatMoney(coupon.value) : `${coupon.value}%`;
    document.getElementById("cart-coupon-applied-text").textContent = `${coupon.code} (-${desc})`;
  } else {
    row.style.display = "flex";
    applied.style.display = "none";
  }
}

function applyCartCoupon() {
  const input = document.getElementById("cart-coupon-input");
  const code = input.value.trim();
  if (!code) {
    showToast("Digite um código de cupom", "error");
    return;
  }

  const req = isBrowserPreview
    ? Promise.resolve({ valid: false })
    : nuiFetch("validateCoupon", { id: state.currentRestaurant.id, code });

  req.then((result) => {
    if (!result || !result.valid) {
      showToast("Cupom inválido, expirado ou esgotado", "error");
      return;
    }
    state.appliedCoupon = { code: result.code, type: result.type, value: result.value };
    input.value = "";
    renderCart();
    showToast(`Cupom "${result.code}" aplicado com sucesso`, "success");
  });
}

function removeCartCoupon() {
  state.appliedCoupon = null;
  renderCart();
}

document.getElementById("cart-coupon-apply-btn").addEventListener("click", applyCartCoupon);
document.getElementById("cart-coupon-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") applyCartCoupon();
});
document.getElementById("cart-coupon-remove-btn").addEventListener("click", removeCartCoupon);

function openCart() {
  renderCart();
  document.getElementById("cart-drawer").classList.add("open");
  document.getElementById("cart-overlay").classList.add("show");
}

function closeCart() {
  document.getElementById("cart-drawer").classList.remove("open");
  document.getElementById("cart-overlay").classList.remove("show");
}

document.getElementById("cart-pill").addEventListener("click", openCart);
document.getElementById("cart-close-btn").addEventListener("click", closeCart);
document.getElementById("cart-overlay").addEventListener("click", closeCart);

document.getElementById("checkout-btn").addEventListener("click", () => {
  const hasItems = Object.values(state.cart).some((i) => i.qty > 0);
  if (!hasItems) {
    showToast("Adicione itens ao carrinho primeiro", "error");
    return;
  }
  openOrderTypeModal();
});

// -------------------------------------------------------------
//  RETIRADA OU ENTREGA (perguntado ao finalizar o pedido)
// -------------------------------------------------------------
function openOrderTypeModal() {
  document.getElementById("order-type-overlay").classList.add("show");
  document.getElementById("order-type-modal").classList.add("open");

  // Retirada pelo tablet pode estar desabilitada via Config.EnableTabletPickupOrders
  // (ex: quando o Atendimento de Balcão passa a cobrir esse caso). O Totem de
  // autoatendimento nunca é afetado por essa flag - continua com as duas opções.
  const pickupBtn = document.getElementById("order-type-pickup-btn");
  pickupBtn.style.display = state.totemMode || state.enablePickupOrders ? "flex" : "none";

  const deliveryBtn = document.getElementById("order-type-delivery-btn");
  deliveryBtn.classList.remove("disabled");
  deliveryBtn.title = "";

  // Entrega só fica disponível com pelo menos 2 funcionários de plantão;
  // consulta o servidor toda vez que o modal abre (o plantão muda em tempo real).
  const req = isBrowserPreview
    ? Promise.resolve({ canDeliver: true })
    : nuiFetch("canDeliver", { id: state.currentRestaurant.id });

  req.then((res) => {
    if (!res || !res.canDeliver) {
      deliveryBtn.classList.add("disabled");
      deliveryBtn.title = "É necessário pelo menos 2 funcionários de plantão para entregas";
    }
  });
}

function closeOrderTypeModal() {
  document.getElementById("order-type-overlay").classList.remove("show");
  document.getElementById("order-type-modal").classList.remove("open");
}

function submitOrder(orderType) {
  const cartArray = Object.values(state.cart)
    .filter((i) => i.qty > 0)
    .map((i) => ({ id: i.id, qty: i.qty }));

  if (cartArray.length === 0) {
    showToast("Adicione itens ao carrinho primeiro", "error");
    closeOrderTypeModal();
    return;
  }

  nuiFetch("placeOrder", {
    id: state.currentRestaurant.id,
    cart: cartArray,
    orderType,
    couponCode: state.appliedCoupon ? state.appliedCoupon.code : null,
    orderSource: state.totemMode ? "totem" : "tablet",
  }).then(() => {
    state.cart = {};
    state.appliedCoupon = null;
    updateCartPill();
    closeCart();
    closeOrderTypeModal();
    showToast(
      orderType === "delivery"
        ? "Pedido enviado para entrega! Aguarde a preparação."
        : "Pedido enviado! Aguarde a preparação.",
      "success"
    );

    if (state.totemMode) {
      // No totem não existe "lista de restaurantes" pra voltar - fica na
      // mesma tela do cardápio, já atualizada, pronta pro próximo cliente.
      openCatalog(state.currentRestaurant.id);
    } else {
      setPage("home");
    }
  });
}

document.getElementById("order-type-pickup-btn").addEventListener("click", () => submitOrder("pickup"));
document.getElementById("order-type-delivery-btn").addEventListener("click", (e) => {
  if (e.currentTarget.classList.contains("disabled")) {
    showToast("É necessário pelo menos 2 funcionários de plantão para entregas", "error");
    return;
  }
  submitOrder("delivery");
});
document.getElementById("order-type-cancel-btn").addEventListener("click", closeOrderTypeModal);
document.getElementById("order-type-overlay").addEventListener("click", closeOrderTypeModal);

// =============================================================
//  PÁGINA: HISTÓRICO DE PEDIDOS (cliente)
// =============================================================
function loadOrderHistory() {
  const container = document.getElementById("history-list");
  container.innerHTML = `<p class="empty-state">Carregando histórico...</p>`;

  const req = isBrowserPreview ? Promise.resolve([]) : nuiFetch("getOrderHistory");
  req.then((history) => {
    state.orderHistory = history || [];
    renderHistory();
  });
}

function formatHistoryDate(timestamp) {
  if (!timestamp) return "";
  const d = new Date(timestamp * 1000);
  const datePart = d.toLocaleDateString("pt-BR");
  const timePart = d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
  return `${datePart} ${timePart}`;
}

function renderHistory() {
  const container = document.getElementById("history-list");
  container.innerHTML = "";

  if (!state.orderHistory || state.orderHistory.length === 0) {
    container.innerHTML = `<p class="empty-state">Você ainda não fez nenhum pedido</p>`;
    return;
  }

  const template = document.getElementById("history-card-template");

  state.orderHistory.forEach((entry) => {
    const node = template.content.cloneNode(true);

    node.querySelector(".history-restaurant-name").textContent = entry.restaurantLabel || "Restaurante";
    node.querySelector(".history-order-time").textContent = formatHistoryDate(entry.createdAt);

    const itemsList = node.querySelector(".history-order-items");
    (entry.items || []).forEach((item) => {
      const li = document.createElement("li");
      li.textContent = `${item.qty}x ${item.name}`;
      itemsList.appendChild(li);
    });

    node.querySelector(".history-order-total").textContent = "Total: " + formatMoney(entry.total);

    node.querySelector(".history-repeat-btn").addEventListener("click", () => repeatOrder(entry));

    container.appendChild(node);
  });
}

// Reabre o cardápio do restaurante do pedido antigo e joga os mesmos itens
// de volta no carrinho, já pronto pra revisar e finalizar de novo. Itens que
// não existem mais, estão desativados ou sem estoque suficiente são pulados.
function repeatOrder(entry) {
  openCatalog(entry.restaurantIndex, (data) => {
    let addedCount = 0;
    const skipped = [];

    (entry.items || []).forEach((histItem) => {
      const menuItem = (data.menu || []).find((m) => m.id === histItem.id);
      if (!menuItem || !menuItem.enabled || menuItem.stock <= 0) {
        skipped.push(histItem.name);
        return;
      }

      const qty = Math.min(histItem.qty, menuItem.stock);
      addToCart(menuItem, qty, true);
      addedCount++;
      if (qty < histItem.qty) skipped.push(menuItem.name);
    });

    if (addedCount === 0) {
      showToast("Nenhum item deste pedido está disponível no momento", "error");
      return;
    }

    if (skipped.length > 0) {
      showToast(`Alguns itens não puderam ser adicionados (esgotados/indisponíveis): ${skipped.join(", ")}`, "info");
    } else {
      showToast("Itens do pedido anterior adicionados ao carrinho!", "success");
    }

    openCart();
  });
}

// =============================================================
//  PÁGINA: COZINHA (funcionário)
// =============================================================
function loadKitchenOrders() {
  const restaurantId = state.employeeRestaurantIndex;
  if (!restaurantId) return;

  const req = isBrowserPreview ? Promise.resolve([]) : nuiFetch("getKitchenOrders", { id: restaurantId });
  req.then((orders) => {
    state.kitchenOrders = { pending: [], preparing: [], ready: [] };
    (orders || []).forEach((order) => {
      if (state.kitchenOrders[order.status]) state.kitchenOrders[order.status].push(order);
    });
    renderKitchen();
  });
}

function loadDeliveryToggleStatus() {
  const restaurantId = state.employeeRestaurantIndex;
  if (!restaurantId) return;

  const req = isBrowserPreview ? Promise.resolve({ paused: false }) : nuiFetch("getDeliveryStatus", { id: restaurantId });
  req.then((res) => {
    renderDeliveryToggle(!!(res && res.paused));
  });
}

function renderDeliveryToggle(paused) {
  const input = document.getElementById("delivery-toggle-input");
  const label = document.getElementById("delivery-toggle-label");
  if (!input || !label) return;

  input.checked = !paused;
  label.textContent = paused ? "Entregas pausadas" : "Entregas ativas";
}

document.getElementById("delivery-toggle-input").addEventListener("change", (e) => {
  const restaurantId = state.employeeRestaurantIndex;
  if (!restaurantId) return;

  const paused = !e.target.checked;
  renderDeliveryToggle(paused);
  nuiFetch("toggleDelivery", { id: restaurantId, paused });
});

function renderKitchen() {
  ["pending", "preparing", "ready"].forEach((status) => {
    const container = document.getElementById(`kitchen-${status}`);
    container.innerHTML = "";

    if (state.kitchenOrders[status].length === 0) {
      container.innerHTML = `<p class="empty-state">Nenhum pedido</p>`;
      return;
    }

    state.kitchenOrders[status].forEach((order) => {
      container.appendChild(buildOrderCard(order));
    });
  });
}

function buildOrderCard(order) {
  const template = document.getElementById("order-card-template");
  const node = template.content.cloneNode(true);
  const card = node.querySelector(".order-card");
  card.dataset.orderId = order.id;

  node.querySelector(".order-id").textContent = "#" + String(order.id).padStart(4, "0");
  node.querySelector(".order-time").textContent = new Date((order.createdAt || 0) * 1000).toLocaleTimeString("pt-BR", {
    hour: "2-digit",
    minute: "2-digit",
  });
  const isDelivery = order.orderType === "delivery";
  const isTotem = order.orderSource === "totem";
  const isCounter = order.orderSource === "counter";
  node.querySelector(".order-customer").innerHTML = `<i class="fas fa-user"></i> ${order.customerName || "Cliente"}
    <span class="order-type-badge ${isDelivery ? "delivery" : "pickup"}">
      <i class="fas ${isDelivery ? "fa-motorcycle" : "fa-store"}"></i> ${isDelivery ? "Entrega" : "Retirada"}
    </span>
    ${isTotem ? `<span class="order-type-badge totem"><i class="fas fa-tablet-screen-button"></i> Totem</span>` : ""}
    ${isCounter ? `<span class="order-type-badge counter"><i class="fas fa-cash-register"></i> Balcão</span>` : ""}`;

  const list = node.querySelector(".order-items");
  order.items.forEach((item) => {
    const li = document.createElement("li");
    li.textContent = `${item.qty}x ${item.name}`;
    list.appendChild(li);
  });

  node.querySelector(".order-total").textContent = "Total: " + formatMoney(order.total);

  const actions = node.querySelector(".order-actions");
  if (order.status === "pending") {
    const btn = document.createElement("button");
    btn.className = "action-btn primary full-width";
    btn.innerHTML = `<i class="fas fa-play"></i> Aceitar Pedido`;
    btn.addEventListener("click", () => {
      nuiFetch("acceptOrder", { orderId: order.id });
    });
    actions.appendChild(btn);
  } else if (order.status === "preparing") {
    const isAssigned = order.employeeId === state.myServerId;
    const btn = document.createElement("button");
    btn.className = "action-btn primary full-width";
    btn.innerHTML = `<i class="fas fa-clipboard-list"></i> Ver Missão de Preparo`;
    btn.addEventListener("click", () => {
      openPrepMission(order, isAssigned);
    });
    actions.appendChild(btn);

    if (!isAssigned) {
      const info = document.createElement("div");
      info.className = "order-preparing-info";
      info.innerHTML = `<i class="fas fa-user-clock"></i> Em preparo por ${order.employeeName || "outro funcionário"}`;
      actions.appendChild(info);
    }
  } else if (order.status === "ready") {
    if (isDelivery && order.deliveryCoords) {
      const routeBtn = document.createElement("button");
      routeBtn.className = "action-btn secondary full-width";
      routeBtn.innerHTML = `<i class="fas fa-location-arrow"></i> Traçar Rota de Entrega`;
      routeBtn.addEventListener("click", () => {
        nuiFetch("setDeliveryRouteWaypoint", { coords: order.deliveryCoords });
      });
      actions.appendChild(routeBtn);
    }

    const btn = document.createElement("button");
    btn.className = "action-btn primary full-width";
    btn.innerHTML = `<i class="fas fa-check-double"></i> Confirmar Entrega`;
    btn.title = "Confirme somente depois de entregar o pedido ao cliente pessoalmente";
    btn.addEventListener("click", () => {
      nuiFetch("completeOrder", { orderId: order.id });
    });
    actions.appendChild(btn);
  }

  return node;
}

function moveOrderInState(order) {
  ["pending", "preparing", "ready"].forEach((status) => {
    state.kitchenOrders[status] = state.kitchenOrders[status].filter((o) => o.id !== order.id);
  });
  if (order.status === "pending" || order.status === "preparing" || order.status === "ready") {
    state.kitchenOrders[order.status].push(order);
  }
}

// =============================================================
//  PÁGINA: ATENDIMENTO (funcionário monta o pedido de um cliente
//  presencial direto no balcão, sem o cliente usar tablet/totem)
// =============================================================
function loadCounterMenu() {
  const restaurantId = state.employeeRestaurantIndex;
  if (!restaurantId) return;

  const req = isBrowserPreview ? Promise.resolve(MOCK_MENU[restaurantId]) : nuiFetch("getMenu", { id: restaurantId });
  req.then((data) => {
    if (!data) {
      showToast("Não foi possível carregar o cardápio", "error");
      return;
    }
    data.id = restaurantId;
    state.counterRestaurant = data;
    renderCounterCatalog();
  });
}

function renderCounterCatalog() {
  const restaurant = state.counterRestaurant;
  if (!restaurant) return;

  const categories = [...new Set(restaurant.menu.map((i) => i.category))];
  const tabsEl = document.getElementById("counter-category-tabs");
  tabsEl.innerHTML = "";
  categories.forEach((cat, idx) => {
    const btn = document.createElement("button");
    btn.className = "filter-btn" + (idx === 0 ? " active" : "");
    btn.textContent = formatCategory(cat);
    btn.dataset.category = cat;
    btn.addEventListener("click", () => {
      tabsEl.querySelectorAll(".filter-btn").forEach((b) => b.classList.remove("active"));
      btn.classList.add("active");
      renderCounterMenuGrid(cat);
    });
    tabsEl.appendChild(btn);
  });

  renderCounterMenuGrid(categories[0]);
}

function renderCounterMenuGrid(category) {
  const grid = document.getElementById("counter-menu-grid");
  grid.innerHTML = "";
  const template = document.getElementById("menu-item-template");
  const restaurant = state.counterRestaurant;

  restaurant.menu
    .filter((item) => item.category === category)
    .forEach((item) => {
      const node = template.content.cloneNode(true);
      const card = node.querySelector(".menu-item-card");
      node.querySelector(".menu-item-img img").src = item.image || "img/placeholder-item.png";
      node.querySelector(".menu-item-name").textContent = item.name;
      node.querySelector(".menu-item-desc").textContent = item.description || "";
      node.querySelector(".menu-item-price").textContent = formatMoney(item.price);

      const qtyValue = node.querySelector(".qty-value");
      let qty = 1;
      node.querySelector(".qty-btn.minus").addEventListener("click", () => {
        qty = Math.max(1, qty - 1);
        qtyValue.textContent = qty;
      });
      node.querySelector(".qty-btn.plus").addEventListener("click", () => {
        qty = Math.min(item.stock, qty + 1);
        qtyValue.textContent = qty;
      });

      const addBtn = node.querySelector(".add-btn");
      if (!item.enabled || item.stock <= 0 || !restaurant.isOpen) {
        addBtn.disabled = true;
        addBtn.innerHTML = `<i class="fas fa-ban"></i> Indisponível`;
        card.classList.add("disabled");
      } else {
        addBtn.addEventListener("click", () => addToCounterCart(item, qty));
      }

      grid.appendChild(node);
    });
}

function addToCounterCart(item, qty) {
  if (!state.counterCart[item.id]) {
    state.counterCart[item.id] = { ...item, qty: 0 };
  }
  state.counterCart[item.id].qty += qty;
  renderCounterOrder();
}

function renderCounterOrder() {
  const container = document.getElementById("counter-order-items");
  container.innerHTML = "";
  const template = document.getElementById("cart-item-template");
  let total = 0;

  Object.values(state.counterCart).forEach((item) => {
    if (item.qty <= 0) return;
    total += item.qty * item.price;
    const node = template.content.cloneNode(true);
    node.querySelector(".cart-item-name").textContent = item.name;
    node.querySelector(".cart-item-price").textContent = formatMoney(item.price * item.qty);
    const qtyValue = node.querySelector(".qty-value");
    qtyValue.textContent = item.qty;

    node.querySelector(".qty-btn.minus").addEventListener("click", () => {
      item.qty -= 1;
      if (item.qty <= 0) delete state.counterCart[item.id];
      renderCounterOrder();
    });
    node.querySelector(".qty-btn.plus").addEventListener("click", () => {
      item.qty += 1;
      renderCounterOrder();
    });

    container.appendChild(node);
  });

  const discount = calcCouponDiscount(total, state.counterAppliedCoupon);
  const finalTotal = Math.max(0, total - discount);

  const discountRow = document.getElementById("counter-discount-row");
  if (discount > 0) {
    discountRow.style.display = "flex";
    document.getElementById("counter-discount").textContent = "- " + formatMoney(discount);
  } else {
    discountRow.style.display = "none";
  }

  document.getElementById("counter-order-total").textContent = formatMoney(finalTotal);
  renderCounterAppliedCoupon();

  if (Object.keys(state.counterCart).length === 0) {
    container.innerHTML = `<p class="empty-state">Nenhum item adicionado</p>`;
  }
}

// -------------------------------------------------------------
//  CUPOM DE DESCONTO NO PEDIDO DE BALCÃO (aplicado pelo funcionário)
// -------------------------------------------------------------
function renderCounterAppliedCoupon() {
  const row = document.getElementById("counter-coupon-row");
  const applied = document.getElementById("counter-coupon-applied");
  const coupon = state.counterAppliedCoupon;

  if (coupon) {
    row.style.display = "none";
    applied.style.display = "flex";
    const desc = coupon.type === "fixed" ? formatMoney(coupon.value) : `${coupon.value}%`;
    document.getElementById("counter-coupon-applied-text").textContent = `${coupon.code} (-${desc})`;
  } else {
    row.style.display = "flex";
    applied.style.display = "none";
  }
}

function applyCounterCoupon() {
  const input = document.getElementById("counter-coupon-input");
  const code = input.value.trim();
  if (!code) {
    showToast("Digite um código de cupom", "error");
    return;
  }

  const req = isBrowserPreview
    ? Promise.resolve({ valid: false })
    : nuiFetch("validateCoupon", { id: state.employeeRestaurantIndex, code });

  req.then((result) => {
    if (!result || !result.valid) {
      showToast("Cupom inválido, expirado ou esgotado", "error");
      return;
    }
    state.counterAppliedCoupon = { code: result.code, type: result.type, value: result.value };
    input.value = "";
    renderCounterOrder();
    showToast(`Cupom "${result.code}" aplicado com sucesso`, "success");
  });
}

function removeCounterCoupon() {
  state.counterAppliedCoupon = null;
  renderCounterOrder();
}

document.getElementById("counter-coupon-apply-btn").addEventListener("click", applyCounterCoupon);
document.getElementById("counter-coupon-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") applyCounterCoupon();
});
document.getElementById("counter-coupon-remove-btn").addEventListener("click", removeCounterCoupon);

function renderCounterCustomer() {
  const selectBtn = document.getElementById("counter-select-customer-btn");
  const selectedBox = document.getElementById("counter-customer-selected");
  const selectedName = document.getElementById("counter-customer-selected-name");

  if (state.counterCustomer) {
    selectBtn.style.display = "none";
    selectedBox.style.display = "flex";
    selectedName.textContent = state.counterCustomer.name;
  } else {
    selectBtn.style.display = "flex";
    selectedBox.style.display = "none";
  }
}

function selectCounterCustomer() {
  nuiFetch("selectCounterCustomer", {}).then((res) => {
    if (!res || !res.ok) {
      showToast("Nenhum cliente por perto pra selecionar", "error");
      return;
    }
    state.counterCustomer = { serverId: res.serverId, name: res.name };
    renderCounterCustomer();
  });
}

function clearCounterCustomer() {
  state.counterCustomer = null;
  renderCounterCustomer();
}

document.getElementById("counter-select-customer-btn").addEventListener("click", selectCounterCustomer);
document.getElementById("counter-customer-clear-btn").addEventListener("click", clearCounterCustomer);

function registerCounterOrder() {
  const cartArray = Object.values(state.counterCart)
    .filter((i) => i.qty > 0)
    .map((i) => ({ id: i.id, qty: i.qty }));

  if (cartArray.length === 0) {
    showToast("Adicione itens ao pedido primeiro", "error");
    return;
  }

  if (!state.counterCustomer) {
    showToast("Selecione um cliente próximo antes de registrar o pedido", "error");
    return;
  }

  const subtotal = Object.values(state.counterCart).reduce((sum, i) => sum + i.qty * i.price, 0);
  const discount = calcCouponDiscount(subtotal, state.counterAppliedCoupon);
  const total = Math.max(0, subtotal - discount);

  nuiFetch("placeCounterOrder", {
    id: state.employeeRestaurantIndex,
    cart: cartArray,
    customerId: state.counterCustomer.serverId,
    couponCode: state.counterAppliedCoupon ? state.counterAppliedCoupon.code : null,
  }).then(() => {
    showToast(`Cobrança de ${formatMoney(total)} enviada para ${state.counterCustomer.name}. Aguardando confirmação...`, "success");
    state.counterCart = {};
    state.counterAppliedCoupon = null;
    state.counterCustomer = null;
    renderCounterCustomer();
    renderCounterOrder();
  });
}

document.getElementById("counter-register-btn").addEventListener("click", registerCounterOrder);

// =============================================================
//  MISSÃO DE PREPARO (exibida ao funcionário que aceitou o pedido)
// =============================================================
let missionOrder = null;
let missionIsAssigned = true;

function openPrepMission(order, isAssigned) {
  missionOrder = order;
  missionIsAssigned = isAssigned !== false;

  document.getElementById("mission-order-id").textContent = "#" + String(order.id).padStart(4, "0");
  const orderTypeLabel = order.orderType === "delivery" ? " (Entrega)" : " (Retirada)";
  document.getElementById("mission-customer").textContent = (order.customerName || "Cliente") + orderTypeLabel;

  // Todos os funcionários veem o preparo em andamento, mas só quem aceitou
  // o pedido pode marcar como pronto.
  const readyBtn = document.getElementById("mission-ready-btn");
  readyBtn.style.display = missionIsAssigned ? "flex" : "none";
  let assignedNote = document.getElementById("mission-assigned-note");
  if (!missionIsAssigned) {
    if (!assignedNote) {
      assignedNote = document.createElement("p");
      assignedNote.id = "mission-assigned-note";
      assignedNote.className = "mission-assigned-note";
      readyBtn.insertAdjacentElement("beforebegin", assignedNote);
    }
    assignedNote.textContent = `Sendo preparado por ${order.employeeName || "outro funcionário"}`;
    assignedNote.style.display = "block";
  } else if (assignedNote) {
    assignedNote.style.display = "none";
  }

  const body = document.getElementById("mission-body");
  body.innerHTML = "";
  const template = document.getElementById("mission-item-template");
  const neededByItem = {}; // { inventoryItemName: totalNeeded } - somado entre todos os produtos do pedido

  (order.items || []).forEach((orderItem) => {
    const node = template.content.cloneNode(true);
    node.querySelector(".mission-objective-text").textContent = `Montar ${orderItem.qty}x ${orderItem.name}`;

    const list = node.querySelector(".mission-recipe-list");
    const recipe = orderItem.recipe && orderItem.recipe.length
      ? orderItem.recipe
      : [{ item: false, label: "Prepare o item com cuidado e capricho" }];

    recipe.forEach((entry) => {
      const hasInventoryCheck = !!entry.item;
      const needed = (entry.qty || 1) * orderItem.qty;

      const li = document.createElement("li");
      li.className = "mission-recipe-line" + (hasInventoryCheck ? "" : " mission-recipe-line-plain");
      const labelText = hasInventoryCheck ? `${needed}x ${entry.label}` : entry.label;
      li.innerHTML = `<i class="fas fa-check-circle"></i><span class="mission-ingredient-label">${labelText}</span><span class="mission-ingredient-count"></span>`;

      if (hasInventoryCheck) {
        li.dataset.item = entry.item;
        li.dataset.needed = needed;
        neededByItem[entry.item] = (neededByItem[entry.item] || 0) + needed;
      }

      list.appendChild(li);
    });

    body.appendChild(node);
  });

  document.getElementById("mission-modal").classList.add("open");

  // Consulta o inventário do funcionário pra cada item real usado na receita
  const itemNames = Object.keys(neededByItem);
  if (itemNames.length > 0) {
    nuiFetch("getRecipeItemCounts", { items: itemNames }).then((counts) => {
      if (!counts || missionOrder !== order) return;
      body.querySelectorAll(".mission-recipe-line[data-item]").forEach((li) => {
        const itemName = li.dataset.item;
        const needed = parseInt(li.dataset.needed, 10) || 0;
        const have = counts[itemName] || 0;
        const countEl = li.querySelector(".mission-ingredient-count");
        countEl.textContent = `${have}/${needed}`;
        countEl.classList.add(have >= needed ? "mission-count-ok" : "mission-count-missing");
        li.classList.toggle("mission-recipe-line-missing", have < needed);
      });
    });
  }
}

function closePrepMission() {
  const wasActive = !!missionOrder;
  document.getElementById("mission-modal").classList.remove("open");
  missionOrder = null;

  const tabletOpen = document.getElementById("tablet-device").classList.contains("tablet-on");
  if (wasActive && !tabletOpen) {
    nuiFetch("missionClosed");
  }
}

document.getElementById("mission-close-btn").addEventListener("click", closePrepMission);
document.getElementById("mission-ready-btn").addEventListener("click", () => {
  if (!missionOrder || !missionIsAssigned) return;
  nuiFetch("markOrderReady", { orderId: missionOrder.id }).then(() => {
    showToast(`Pedido #${missionOrder.id} marcado como pronto!`, "success");
    closePrepMission();
  });
});

// =============================================================
//  PÁGINA: GERÊNCIA
// =============================================================
function openManage(restaurantId) {
  const req = isBrowserPreview
    ? Promise.resolve({ label: "Burger Shot", menu: MOCK_MENU[1].menu, balance: 1240 })
    : nuiFetch("accessManagement", { id: restaurantId });

  req.then((data) => {
    if (!data || data === "unauthorized" || data === "error") {
      showToast("Você não tem permissões de gerente para este restaurante", "error");
      return;
    }
    data.id = restaurantId;
    state.manageData = data;
    state.manageSubpage = "catalog";
    document.querySelectorAll(".manage-subnav .filter-btn").forEach((b) => b.classList.remove("active"));
    document.querySelector('.manage-subnav .filter-btn[data-subpage="catalog"]').classList.add("active");
    document.getElementById("manage-subpage-catalog").style.display = "block";
    document.getElementById("manage-subpage-coupons").style.display = "none";
    document.getElementById("manage-subpage-sales").style.display = "none";
    document.getElementById("manage-subpage-stocklog").style.display = "none";
    document.getElementById("manage-subpage-dashboard").style.display = "none";
    renderManage();
    setPage("manage");
  });
}

function renderManage() {
  const data = state.manageData;
  document.getElementById("manage-balance").textContent = formatMoney(data.balance);

  const container = document.getElementById("manage-items");
  container.innerHTML = "";
  const template = document.getElementById("manage-item-template");

  data.menu.forEach((item) => {
    const node = template.content.cloneNode(true);
    node.querySelector(".manage-item-img").src = item.image || "img/placeholder-item.png";
    node.querySelector(".manage-item-name").textContent = item.name;

    const priceInput = node.querySelector(".manage-price-input");
    const enabledInput = node.querySelector(".manage-enabled-input");

    priceInput.value = item.price;
    enabledInput.checked = item.enabled;

    function pushChanges() {
      nuiFetch("updateMenuItem", {
        id: data.id,
        itemId: item.id,
        changes: {
          price: Number(priceInput.value),
          enabled: enabledInput.checked,
        },
      });
    }

    priceInput.addEventListener("change", pushChanges);
    enabledInput.addEventListener("change", pushChanges);

    container.appendChild(node);
  });
}

document.querySelectorAll(".manage-subnav .filter-btn").forEach((btn) => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".manage-subnav .filter-btn").forEach((b) => b.classList.remove("active"));
    btn.classList.add("active");
    state.manageSubpage = btn.dataset.subpage;
    document.getElementById("manage-subpage-catalog").style.display = state.manageSubpage === "catalog" ? "block" : "none";
    document.getElementById("manage-subpage-coupons").style.display = state.manageSubpage === "coupons" ? "block" : "none";
    document.getElementById("manage-subpage-sales").style.display = state.manageSubpage === "sales" ? "block" : "none";
    document.getElementById("manage-subpage-stocklog").style.display = state.manageSubpage === "stocklog" ? "block" : "none";
    document.getElementById("manage-subpage-dashboard").style.display = state.manageSubpage === "dashboard" ? "block" : "none";
    if (state.manageSubpage === "coupons") loadCoupons();
    if (state.manageSubpage === "sales") loadSalesLog();
    if (state.manageSubpage === "stocklog") loadManageStockLog();
    if (state.manageSubpage === "dashboard") loadDashboard();
  });
});

// -------------------------------------------------------------
//  CUPONS DE DESCONTO (dono/gerente)
// -------------------------------------------------------------
function loadCoupons() {
  const req = isBrowserPreview ? Promise.resolve([]) : nuiFetch("getCoupons", { id: state.manageData.id });
  req.then((coupons) => {
    state.coupons = coupons || [];
    renderCoupons();
  });
}

function renderCoupons() {
  const container = document.getElementById("manage-coupons");
  container.innerHTML = "";

  if (state.coupons.length === 0) {
    container.innerHTML = `<p class="empty-state">Nenhum cupom criado ainda</p>`;
    return;
  }

  const template = document.getElementById("coupon-card-template");
  state.coupons.forEach((coupon) => {
    const node = template.content.cloneNode(true);
    node.querySelector(".coupon-code").textContent = coupon.code;

    const discountText = coupon.type === "fixed" ? formatMoney(coupon.value) : `${coupon.value}%`;
    const expiresText = coupon.expiresAt
      ? ` · expira em ${new Date(coupon.expiresAt * 1000).toLocaleDateString("pt-BR")}`
      : "";
    node.querySelector(".coupon-details").textContent = `Desconto de ${discountText}${expiresText}`;

    const usesText = coupon.maxUses > 0 ? `${coupon.uses}/${coupon.maxUses} usos` : `${coupon.uses} usos · ilimitado`;
    node.querySelector(".coupon-usage").textContent = usesText;

    const activeInput = node.querySelector(".coupon-active-input");
    activeInput.checked = coupon.active;
    activeInput.addEventListener("change", () => {
      nuiFetch("toggleCoupon", { id: state.manageData.id, couponId: coupon.id, active: activeInput.checked });
      coupon.active = activeInput.checked;
    });

    node.querySelector(".coupon-delete-btn").addEventListener("click", () => {
      nuiFetch("deleteCoupon", { id: state.manageData.id, couponId: coupon.id }).then(() => {
        state.coupons = state.coupons.filter((c) => c.id !== coupon.id);
        renderCoupons();
      });
    });

    container.appendChild(node);
  });
}

function openNewCouponDrawer() {
  document.getElementById("new-coupon-drawer").classList.add("open");
  document.getElementById("new-coupon-overlay").classList.add("show");
}

function closeNewCouponDrawer() {
  document.getElementById("new-coupon-drawer").classList.remove("open");
  document.getElementById("new-coupon-overlay").classList.remove("show");
}

document.getElementById("new-coupon-btn").addEventListener("click", openNewCouponDrawer);
document.getElementById("new-coupon-close-btn").addEventListener("click", closeNewCouponDrawer);
document.getElementById("new-coupon-overlay").addEventListener("click", closeNewCouponDrawer);

document.getElementById("new-coupon-submit").addEventListener("click", () => {
  const code = document.getElementById("new-coupon-code").value.trim();
  const type = document.getElementById("new-coupon-type").value;
  const value = Number(document.getElementById("new-coupon-value").value) || 0;
  const maxUses = Math.max(0, Number(document.getElementById("new-coupon-maxuses").value) || 0);
  const expiresInDays = Math.max(0, Number(document.getElementById("new-coupon-expires").value) || 0);

  if (!code || value <= 0) {
    showToast("Preencha um código e um valor de desconto válidos", "error");
    return;
  }

  nuiFetch("createCoupon", {
    id: state.manageData.id,
    coupon: { code, type, value, maxUses, expiresInDays },
  }).then(() => {
    showToast(`Cupom "${code.toUpperCase()}" criado com sucesso`, "success");
    closeNewCouponDrawer();
    document.getElementById("new-coupon-code").value = "";
    document.getElementById("new-coupon-value").value = 10;
    document.getElementById("new-coupon-maxuses").value = 0;
    document.getElementById("new-coupon-expires").value = 0;
    loadCoupons();
  });
});

// -------------------------------------------------------------
//  NOVO ITEM DO CARDÁPIO (dono/gerente)
// -------------------------------------------------------------
function openNewItemDrawer() {
  document.getElementById("new-item-drawer").classList.add("open");
  document.getElementById("new-item-overlay").classList.add("show");
}

function closeNewItemDrawer() {
  document.getElementById("new-item-drawer").classList.remove("open");
  document.getElementById("new-item-overlay").classList.remove("show");
}

document.getElementById("new-item-btn").addEventListener("click", openNewItemDrawer);
document.getElementById("new-item-close-btn").addEventListener("click", closeNewItemDrawer);
document.getElementById("new-item-overlay").addEventListener("click", closeNewItemDrawer);

document.getElementById("new-item-submit").addEventListener("click", () => {
  const name = document.getElementById("new-item-name").value.trim();
  const description = document.getElementById("new-item-desc").value.trim();
  const category = document.getElementById("new-item-category").value.trim();
  const price = Number(document.getElementById("new-item-price").value) || 0;
  const item = document.getElementById("new-item-inv").value.trim();
  const stock = Math.max(0, Number(document.getElementById("new-item-stock").value) || 0);
  const prepTime = Math.max(0, Number(document.getElementById("new-item-preptime").value) || 10);
  const image = document.getElementById("new-item-image").value.trim();

  if (!name || !category || !item) {
    showToast("Preencha ao menos nome, categoria e item do inventário", "error");
    return;
  }

  nuiFetch("createMenuItem", {
    id: state.manageData.id,
    item: { name, description, category, price, item, stock, prepTime, image },
  }).then(() => {
    showToast(`Item "${name}" criado com sucesso`, "success");
    closeNewItemDrawer();
    ["new-item-name", "new-item-desc", "new-item-category", "new-item-inv", "new-item-image"].forEach((id) => {
      document.getElementById(id).value = "";
    });
    document.getElementById("new-item-price").value = 0;
    document.getElementById("new-item-stock").value = 0;
    document.getElementById("new-item-preptime").value = 10;
  });
});

function loadSalesLog() {
  const req = isBrowserPreview ? Promise.resolve([]) : nuiFetch("getSalesLog", { id: state.manageData.id });
  req.then((sales) => {
    state.salesLog = sales || [];
    renderSalesLog();
  });
}

function renderSalesLog() {
  const container = document.getElementById("sales-list");
  container.innerHTML = "";

  if (state.salesLog.length === 0) {
    container.innerHTML = `<p class="empty-state">Nenhuma venda registrada ainda</p>`;
    return;
  }

  const template = document.getElementById("sale-card-template");
  state.salesLog.forEach((sale) => {
    const node = template.content.cloneNode(true);
    node.querySelector(".sale-employee span").textContent = sale.employeeName || "Funcionário";
    node.querySelector(".sale-time").textContent = new Date((sale.createdAt || 0) * 1000).toLocaleString("pt-BR", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });

    const list = node.querySelector(".sale-items");
    sale.items.forEach((item) => {
      const li = document.createElement("li");
      li.textContent = `${item.qty}x ${item.name}`;
      list.appendChild(li);
    });

    node.querySelector(".sale-total").textContent = "Total: " + formatMoney(sale.total);
    container.appendChild(node);
  });
}

// -------------------------------------------------------------
//  DASHBOARD (dono/gerente) - itens vendidos por quantidade, em pizza
// -------------------------------------------------------------
const DASHBOARD_PIE_COLORS = [
  "#3b82f6", "#f0b429", "#22c55e", "#ef4444", "#a855f7",
  "#06b6d4", "#f97316", "#ec4899", "#84cc16", "#6366f1",
];

function loadDashboard() {
  const req = isBrowserPreview
    ? Promise.resolve([
        { name: "X-Burger", qty: 42 },
        { name: "Batata Frita", qty: 30 },
        { name: "Coca-Cola", qty: 21 },
      ])
    : nuiFetch("getItemsSoldStats", { id: state.manageData.id });

  req.then((stats) => {
    state.dashboardStats = stats || [];
    renderDashboard();
  });
}

function renderDashboard() {
  const container = document.getElementById("dashboard-content");
  container.innerHTML = "";

  const stats = state.dashboardStats || [];
  const totalQty = stats.reduce((sum, s) => sum + (s.qty || 0), 0);

  if (stats.length === 0 || totalQty === 0) {
    container.innerHTML = `<p class="empty-state">Nenhuma venda registrada ainda</p>`;
    return;
  }

  // Monta o conic-gradient (pizza) fatia por fatia, na ordem de mais vendido pro menos
  let acc = 0;
  const gradientStops = stats.map((s, i) => {
    const color = DASHBOARD_PIE_COLORS[i % DASHBOARD_PIE_COLORS.length];
    const start = (acc / totalQty) * 360;
    acc += s.qty;
    const end = (acc / totalQty) * 360;
    return `${color} ${start}deg ${end}deg`;
  });

  const wrapper = document.createElement("div");
  wrapper.className = "dashboard-summary";
  wrapper.innerHTML = `<span class="dashboard-total-label">Total de itens vendidos</span><span class="dashboard-total-value">${totalQty}</span>`;
  container.appendChild(wrapper);

  const chartRow = document.createElement("div");
  chartRow.className = "dashboard-chart-row";

  const pie = document.createElement("div");
  pie.className = "dashboard-pie-chart";
  pie.style.background = `conic-gradient(${gradientStops.join(", ")})`;
  chartRow.appendChild(pie);

  const legend = document.createElement("ul");
  legend.className = "dashboard-legend";
  stats.forEach((s, i) => {
    const color = DASHBOARD_PIE_COLORS[i % DASHBOARD_PIE_COLORS.length];
    const pct = ((s.qty / totalQty) * 100).toFixed(1);
    const li = document.createElement("li");
    li.className = "dashboard-legend-item";
    li.innerHTML = `
      <span class="dashboard-legend-dot" style="background:${color}"></span>
      <span class="dashboard-legend-name">${s.name}</span>
      <span class="dashboard-legend-value">${s.qty}x <small>(${pct}%)</small></span>
    `;
    legend.appendChild(li);
  });
  chartRow.appendChild(legend);

  container.appendChild(chartRow);
}

// =============================================================
//  PÁGINA: ESTOQUE (qualquer funcionário abastece/retira)
// =============================================================
function loadStockData() {
  const restaurantId = state.employeeRestaurantIndex;
  if (!restaurantId) return;

  const req = isBrowserPreview
    ? Promise.resolve({ menu: MOCK_MENU[1].menu, log: [] })
    : nuiFetch("getStockData", { id: restaurantId });

  req.then((data) => {
    if (!data) return;
    data.id = restaurantId;
    state.stockData = data;
    renderStock();
  });
}

function renderStock() {
  const data = state.stockData;
  const container = document.getElementById("stock-items");
  container.innerHTML = "";
  const template = document.getElementById("stock-item-template");

  data.menu.forEach((item) => {
    const node = template.content.cloneNode(true);
    node.querySelector(".stock-item-img").src = item.image || "img/placeholder-item.png";
    node.querySelector(".stock-item-name").textContent = item.name;
    node.querySelector(".stock-item-current").textContent = `${item.stock} em estoque`;

    const qtyInput = node.querySelector(".stock-qty-input");

    node.querySelector(".stock-add-btn").addEventListener("click", () => {
      const qty = Math.max(1, Number(qtyInput.value) || 1);
      nuiFetch("addStock", { id: data.id, itemId: item.id, qty }).then(() => loadStockData());
    });

    node.querySelector(".stock-remove-btn").addEventListener("click", () => {
      const qty = Math.max(1, Number(qtyInput.value) || 1);
      nuiFetch("removeStock", { id: data.id, itemId: item.id, qty }).then(() => loadStockData());
    });

    container.appendChild(node);
  });

}

// -------------------------------------------------------------
//  REGISTRO DE ESTOQUE (agora dentro da aba Gerenciar, só dono/gerente)
// -------------------------------------------------------------
function loadManageStockLog() {
  if (!state.manageData) return;
  const req = isBrowserPreview ? Promise.resolve([]) : nuiFetch("getManageStockLog", { id: state.manageData.id });
  req.then((log) => {
    state.manageStockLog = log || [];
    renderManageStockLog();
  });
}

function renderManageStockLog() {
  const container = document.getElementById("manage-stock-log");
  container.innerHTML = "";
  const log = state.manageStockLog || [];

  if (log.length === 0) {
    container.innerHTML = `<p class="empty-state">Nenhuma movimentação registrada ainda</p>`;
    return;
  }

  const template = document.getElementById("stock-log-entry-template");
  log.forEach((entry) => {
    const node = template.content.cloneNode(true);
    const icon = node.querySelector(".stock-log-icon i");
    icon.className = entry.action === "add" ? "fas fa-arrow-up" : "fas fa-arrow-down";
    node.querySelector(".stock-log-icon").classList.add(entry.action === "add" ? "in" : "out");

    const actionText = entry.action === "add" ? "adicionou" : "retirou";
    node.querySelector(".stock-log-main").textContent = `${entry.employeeName} ${actionText} ${entry.qty}x ${entry.item}`;
    node.querySelector(".stock-log-time").textContent = new Date((entry.createdAt || 0) * 1000).toLocaleString("pt-BR", {
      day: "2-digit",
      month: "2-digit",
      hour: "2-digit",
      minute: "2-digit",
    });

    container.appendChild(node);
  });
}

function openWithdrawModal() {
  document.getElementById("withdraw-amount-input").value = "";
  document.getElementById("withdraw-overlay").classList.add("show");
  document.getElementById("withdraw-modal").classList.add("open");
  document.getElementById("withdraw-amount-input").focus();
}

function closeWithdrawModal() {
  document.getElementById("withdraw-overlay").classList.remove("show");
  document.getElementById("withdraw-modal").classList.remove("open");
}

function confirmWithdraw() {
  const amount = document.getElementById("withdraw-amount-input").value;
  if (!amount || isNaN(amount) || Number(amount) <= 0) {
    showToast("Informe um valor válido", "error");
    return;
  }
  nuiFetch("withdrawTill", { id: state.manageData.id, amount: Number(amount) }).then(() => {
    state.manageData.balance -= Number(amount);
    renderManage();
    showToast("Saque realizado com sucesso", "success");
    closeWithdrawModal();
  });
}

document.getElementById("withdraw-btn").addEventListener("click", openWithdrawModal);
document.getElementById("withdraw-cancel-btn").addEventListener("click", closeWithdrawModal);
document.getElementById("withdraw-overlay").addEventListener("click", closeWithdrawModal);
document.getElementById("withdraw-confirm-btn").addEventListener("click", confirmWithdraw);
document.getElementById("withdraw-amount-input").addEventListener("keydown", (e) => {
  if (e.key === "Enter") confirmWithdraw();
});

// =============================================================
//  NAVEGAÇÃO
// =============================================================
document.getElementById("back-btn").addEventListener("click", () => setPage("home"));

document.querySelectorAll(".nav-btn[data-page]").forEach((btn) => {
  btn.addEventListener("click", () => {
    const page = btn.dataset.page;
    if (page === "kitchen") {
      loadKitchenOrders();
      loadDeliveryToggleStatus();
    }
    if (page === "counter") {
      loadCounterMenu();
      state.counterCustomer = null;
      renderCounterCustomer();
    }
    if (page === "stock") {
      loadStockData();
    }
    if (page === "history") {
      loadOrderHistory();
    }
    if (page === "manage" && state.employeeRestaurantIndex) {
      openManage(state.employeeRestaurantIndex);
    }
    setPage(page);
  });
});

document.getElementById("close-app").addEventListener("click", closeApp);

function closeApp() {
  nuiFetch("closeMenu", { missionActive: !!missionOrder });
  document.getElementById("tablet-device").classList.remove("tablet-on");
  document.getElementById("tablet-device").classList.add("tablet-off");
  state.totemMode = false;
  document.body.classList.remove("totem-mode");
}

document.addEventListener("keyup", (e) => {
  if (e.key === "Escape") closeApp();
});

// =============================================================
//  MENSAGENS VINDAS DO CLIENT.LUA
// =============================================================
window.addEventListener("message", (event) => {
  const data = event.data;

  switch (data.action) {
    case "openMenu": {
      state.restaurants = data.restaurants;
      state.job = data.job;
      state.grade = data.grade;
      state.onDuty = data.onDuty;
      state.employeeRestaurantIndex = data.employeeRestaurantIndex;
      state.myServerId = data.playerServerId;
      state.totemMode = false;
      state.enablePickupOrders = data.enablePickupOrders !== false;
      document.body.classList.remove("totem-mode");
      document.getElementById("tablet-device").classList.remove("tablet-off");
      document.getElementById("tablet-device").classList.add("tablet-on");
      setPage("home");
      renderHome();
      break;
    }
    case "openTotemMenu": {
      // Totem de autoatendimento: qualquer cliente pode abrir, direto no
      // cardápio de UM restaurante específico, sem lista/abas de funcionário.
      state.totemMode = true;
      state.myServerId = data.playerServerId;
      state.restaurants = [
        {
          id: data.restaurant.id,
          name: data.restaurant.name,
          label: data.restaurant.label,
          logo: data.restaurant.logo,
          banner: data.restaurant.banner,
          status: data.restaurant.isOpen,
        },
      ];
      state.currentRestaurant = data.restaurant;
      state.cart = {};
      state.appliedCoupon = null;
      document.body.classList.add("totem-mode");
      document.getElementById("tablet-device").classList.remove("tablet-off");
      document.getElementById("tablet-device").classList.add("tablet-on");
      renderCatalog();
      setPage("catalog");
      break;
    }
    case "restaurantStateChanged": {
      const r = state.restaurants.find((r) => r.id === data.restaurantIndex);
      if (r) r.status = data.isOpen;
      if (state.currentPage === "home") renderHome();
      break;
    }
    case "newOrder": {
      if (state.employeeRestaurantIndex === data.order.restaurantIndex) {
        state.kitchenOrders.pending.push(data.order);
        if (state.currentPage === "kitchen") renderKitchen();
        showToast(`Novo pedido #${data.order.id} recebido!`, "info");
      }
      break;
    }
    case "orderUpdated": {
      moveOrderInState(data.order);
      if (state.currentPage === "kitchen") renderKitchen();
      break;
    }
    case "orderReady": {
      showToast(`Seu pedido #${data.order.id} está pronto! Vá até o balcão.`, "success");
      break;
    }
    case "deliveryStatusChanged": {
      if (state.employeeRestaurantIndex === data.id && state.currentPage === "kitchen") {
        renderDeliveryToggle(!!data.paused);
      }
      break;
    }
    case "showPrepMission": {
      openPrepMission(data.order, data.isAssigned);
      break;
    }
    case "menuUpdated": {
      if (state.currentRestaurant && state.currentRestaurant.id === data.restaurantIndex) {
        state.currentRestaurant.menu = data.menu;
        if (state.currentPage === "catalog") renderCatalog();
      }
      if (state.stockData && state.stockData.id === data.restaurantIndex) {
        state.stockData.menu = data.menu;
        if (state.currentPage === "stock") renderStock();
      }
      if (state.manageData && state.manageData.id === data.restaurantIndex) {
        state.manageData.menu = data.menu;
        if (state.currentPage === "manage" && state.manageSubpage === "catalog") renderManage();
      }
      break;
    }
    case "stockLogUpdated": {
      if (
        state.manageData &&
        state.manageData.id === data.restaurantIndex &&
        state.currentPage === "manage" &&
        state.manageSubpage === "stocklog"
      ) {
        loadManageStockLog();
      }
      break;
    }
    case "balanceUpdated": {
      if (state.manageData && state.manageData.id === data.restaurantIndex) {
        state.manageData.balance = data.balance;
        if (state.currentPage === "manage") renderManage();
      }
      break;
    }
    case "showRestaurantNotification": {
      showToast(data.message, data.isOpen ? "success" : "info");
      break;
    }
    case "couponsUpdated": {
      if (
        state.manageData &&
        state.manageData.id === data.restaurantIndex &&
        state.currentPage === "manage" &&
        state.manageSubpage === "coupons"
      ) {
        state.coupons = data.coupons || [];
        renderCoupons();
      }
      break;
    }
  }
});

// =============================================================
//  PRÉ-VISUALIZAÇÃO NO NAVEGADOR (fora do jogo)
// =============================================================
if (isBrowserPreview) {
  window.addEventListener("DOMContentLoaded", () => {
    state.restaurants = MOCK_RESTAURANTS;
    state.employeeRestaurantIndex = 1;
    document.getElementById("tablet-device").classList.remove("tablet-off");
    document.getElementById("tablet-device").classList.add("tablet-on");
    setPage("home");
    renderHome();
  });
}
