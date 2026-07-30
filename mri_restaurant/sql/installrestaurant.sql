-- --------------------------------------------------------
-- Servidor:                     127.0.0.1
-- Versão do servidor:           10.4.32-MariaDB - mariadb.org binary distribution
-- OS do Servidor:               Win64
-- HeidiSQL Versão:              12.20.0.7320
-- --------------------------------------------------------

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET NAMES utf8 */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


-- Copiando estrutura do banco de dados para mri_server
CREATE DATABASE IF NOT EXISTS `mri_server` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;
USE `mri_server`;

-- Copiando estrutura para tabela mri_server.rm_restaurant_coupons
CREATE TABLE IF NOT EXISTS `rm_restaurant_coupons` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_index` int(11) NOT NULL,
  `code` varchar(32) NOT NULL,
  `type` varchar(10) NOT NULL DEFAULT 'percent',
  `value` int(11) NOT NULL DEFAULT 0,
  `max_uses` int(11) NOT NULL DEFAULT 0,
  `uses` int(11) NOT NULL DEFAULT 0,
  `expires_at` int(11) NOT NULL DEFAULT 0,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Copiando dados para a tabela mri_server.rm_restaurant_coupons: ~0 rows (aproximadamente)
INSERT INTO `rm_restaurant_coupons` (`id`, `restaurant_index`, `code`, `type`, `value`, `max_uses`, `uses`, `expires_at`, `active`, `created_at`) VALUES
	(1, 1, 'DENTISTA', 'percent', 10, 0, 4, 0, 1, 1783476819);

-- Copiando estrutura para tabela mri_server.rm_restaurant_data
CREATE TABLE IF NOT EXISTS `rm_restaurant_data` (
  `restaurant_index` int(11) NOT NULL,
  `balance` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`restaurant_index`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Copiando dados para a tabela mri_server.rm_restaurant_data: ~2 rows (aproximadamente)
INSERT INTO `rm_restaurant_data` (`restaurant_index`, `balance`) VALUES
	(1, 903),
	(2, 0);

-- Copiando estrutura para tabela mri_server.rm_restaurant_menu
CREATE TABLE IF NOT EXISTS `rm_restaurant_menu` (
  `restaurant_index` int(11) NOT NULL,
  `item_id` int(11) NOT NULL,
  `category` varchar(50) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` varchar(255) NOT NULL DEFAULT '',
  `price` int(11) NOT NULL DEFAULT 0,
  `item` varchar(100) NOT NULL,
  `image` varchar(255) NOT NULL DEFAULT '',
  `enabled` tinyint(1) NOT NULL DEFAULT 1,
  `stock` int(11) NOT NULL DEFAULT 0,
  `prep_time` int(11) NOT NULL DEFAULT 10,
  `recipe` longtext DEFAULT NULL,
  PRIMARY KEY (`restaurant_index`,`item_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Copiando dados para a tabela mri_server.rm_restaurant_menu: ~10 rows (aproximadamente)
INSERT INTO `rm_restaurant_menu` (`restaurant_index`, `item_id`, `category`, `name`, `description`, `price`, `item`, `image`, `enabled`, `stock`, `prep_time`, `recipe`) VALUES
	(1, 1, 'lanches', 'X-Burger', 'Pão, carne, queijo, alface e tomate', 25, 'burger', 'img/items/xburger.png', 1, 62, 20, '[\r\n  {"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)","qty":1},\r\n  {"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)","qty":1},\r\n  {"item":"rm_queijo_prato","label":"Queijo Prato (fatia)","qty":2},\r\n  {"item":"rm_maionese","label":"Maionese Especial","qty":1},\r\n  {"item":"rm_alface_tomate","label":"Alface e Tomate","qty":1}\r\n]'),
	(1, 2, 'lanches', 'Cheeseburger Duplo', 'Dois hambúrgueres e queijo cheddar', 38, 'rm_double_cheese', 'img/items/double_cheese.png', 0, 39, 25, '[\r\n  {"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)","qty":1},\r\n  {"item":"rm_carne_bovina","label":"Hambúrguer Bovino (160g)","qty":2},\r\n  {"item":"rm_queijo_cheddar","label":"Queijo Cheddar (fatia)","qty":2},\r\n  {"item":"rm_molho_especial","label":"Molho Especial","qty":1},\r\n  {"item":"rm_cebola_caramelizada","label":"Cebola Caramelizada","qty":1}\r\n]'),
	(1, 3, 'acompanhamentos', 'Batata Frita', 'Porção individual de batatas fritas', 12, 'rm_fries', 'img/items/fries.png', 1, 60, 15, '[\r\n  {"item":"rm_batata_congelada","label":"Batata Palito Congelada","qty":1},\r\n  {"item":"rm_sal_temperado","label":"Sal Temperado","qty":1},\r\n  {"item":false,"label":"1 fritada no óleo quente (3 min)"}\r\n]'),
	(1, 4, 'bebidas', 'Coca-Cola', 'Refrigerante gelado 500ml', 8, 'cola', 'img/items/cola.png', 1, 40, 5, '[\r\n  {"item":"rm_lata_cola","label":"Lata/Garrafa Coca-Cola gelada","qty":1},\r\n  {"item":"rm_gelo","label":"Gelo (copo)","qty":1}\r\n]'),
	(1, 5, 'bebidas', 'Suco de Laranja', 'Suco natural de laranja', 10, 'sprunk', 'img/items/orange_juice.png', 1, 50, 5, '[\r\n  {"item":"rm_laranja","label":"Laranjas frescas","qty":3},\r\n  {"item":"rm_gelo","label":"Gelo (porção)","qty":1},\r\n  {"item":false,"label":"1 copo para servir"}\r\n]'),
	(1, 6, 'bebidas', 'shake', 'milkshake', 100, 'rm_milkshake', 'img/placeholder-item.png', 0, 29, 10, '[]'),
	(2, 1, 'bebidas_quentes', 'Café Expresso', 'Café puro e encorpado', 9, 'rm_espresso', 'img/items/espresso.png', 1, 60, 10, '[\r\n  {"item":"rm_cafe_moido","label":"Café Moído (dose)","qty":1},\r\n  {"item":false,"label":"Extração na máquina (30s)"}\r\n]'),
	(2, 2, 'bebidas_quentes', 'Cappuccino', 'Café com espuma de leite e canela', 14, 'rm_cappuccino', 'img/items/cappuccino.png', 1, 45, 15, '[\r\n  {"item":"rm_cafe_moido","label":"Café Moído (dose)","qty":1},\r\n  {"item":"rm_leite","label":"Leite Vaporizado (porção)","qty":1},\r\n  {"item":"rm_canela","label":"Canela (pitada)","qty":1}\r\n]'),
	(2, 3, 'doces', 'Fatia de Bolo', 'Bolo de chocolate caseiro', 16, 'rm_cake_slice', 'img/items/cake_slice.png', 1, 30, 10, '[\r\n  {"item":"rm_bolo_chocolate","label":"Fatia de Bolo de Chocolate","qty":1},\r\n  {"item":"rm_calda_chocolate","label":"Calda de Chocolate (porção)","qty":1}\r\n]'),
	(2, 4, 'bebidas_frias', 'Chá Gelado', 'Chá gelado de pêssego', 11, 'rm_iced_tea', 'img/items/iced_tea.png', 1, 40, 8, '[\r\n  {"item":"rm_cha_pessego","label":"Chá de Pêssego concentrado (dose)","qty":1},\r\n  {"item":"rm_gelo","label":"Gelo (porção)","qty":1}\r\n]');

-- Copiando estrutura para tabela mri_server.rm_restaurant_order_history
CREATE TABLE IF NOT EXISTS `rm_restaurant_order_history` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `citizenid` varchar(50) NOT NULL,
  `order_id` int(11) NOT NULL,
  `restaurant_index` int(11) NOT NULL,
  `items` longtext NOT NULL,
  `total` int(11) NOT NULL DEFAULT 0,
  `discount` int(11) NOT NULL DEFAULT 0,
  `coupon_code` varchar(32) DEFAULT NULL,
  `order_type` varchar(10) NOT NULL DEFAULT 'pickup',
  `order_source` varchar(10) NOT NULL DEFAULT 'tablet',
  `created_at` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_citizenid` (`citizenid`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Copiando dados para a tabela mri_server.rm_restaurant_order_history: ~4 rows (aproximadamente)
INSERT INTO `rm_restaurant_order_history` (`id`, `citizenid`, `order_id`, `restaurant_index`, `items`, `total`, `discount`, `coupon_code`, `order_type`, `order_source`, `created_at`) VALUES
	(1, 'A198FS16', 1, 1, '[{"id":1,"item":"burger","name":"X-Burger","recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"prepTime":20,"qty":1,"price":25}]', 25, 0, NULL, 'delivery', 'tablet', 1783995609),
	(2, 'A198FS16', 2, 1, '[{"id":1,"item":"burger","name":"X-Burger","recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"prepTime":20,"qty":1,"price":25}]', 25, 0, NULL, 'delivery', 'tablet', 1783995618),
	(3, 'A198FS16', 3, 1, '[{"id":1,"item":"burger","name":"X-Burger","recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"prepTime":20,"qty":1,"price":25}]', 25, 0, NULL, 'delivery', 'tablet', 1783995634),
	(4, 'A198FS16', 4, 1, '[{"id":1,"item":"burger","name":"X-Burger","recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"prepTime":20,"qty":5,"price":25}]', 125, 0, NULL, 'delivery', 'tablet', 1783995643),
	(5, 'A198FS16', 5, 1, '[{"id":1,"item":"burger","name":"X-Burger","recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"prepTime":20,"qty":7,"price":25}]', 175, 0, NULL, 'delivery', 'tablet', 1783995652);

-- Copiando estrutura para tabela mri_server.rm_restaurant_sales
CREATE TABLE IF NOT EXISTS `rm_restaurant_sales` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `order_id` int(11) NOT NULL DEFAULT 0,
  `restaurant_index` int(11) NOT NULL,
  `employee_id` int(11) NOT NULL DEFAULT 0,
  `employee_name` varchar(100) NOT NULL DEFAULT '',
  `customer_name` varchar(100) NOT NULL DEFAULT '',
  `items` longtext NOT NULL,
  `total` int(11) NOT NULL DEFAULT 0,
  `created_at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_restaurant` (`restaurant_index`)
) ENGINE=InnoDB AUTO_INCREMENT=38 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Copiando dados para a tabela mri_server.rm_restaurant_sales: ~34 rows (aproximadamente)
INSERT INTO `rm_restaurant_sales` (`id`, `order_id`, `restaurant_index`, `employee_id`, `employee_name`, `customer_name`, `items`, `total`, `created_at`) VALUES
	(1, 1, 1, 3, 'Dentista Dev', 'Dentista Dev', '[{"id":1,"price":25,"prepTime":20,"name":"X-Burger","item":"burger","qty":1},{"id":4,"price":8,"prepTime":5,"name":"Coca-Cola","item":"cola","qty":1}]', 33, 1783387699),
	(2, 1, 1, 3, 'Dentista Dev', 'Dentista Dev', '[{"price":25,"id":1,"qty":1,"name":"X-Burger","item":"burger","prepTime":20}]', 25, 1783388346),
	(3, 3, 1, 3, 'Dentista Dev', 'Alors Staff', '[{"price":25,"id":1,"qty":10,"name":"X-Burger","item":"burger","prepTime":20}]', 250, 1783389192),
	(4, 4, 1, 3, 'Dentista Dev', 'Alors Staff', '[{"price":25,"id":1,"qty":1,"name":"X-Burger","item":"burger","prepTime":20}]', 25, 1783389230),
	(5, 1, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"name":"X-Burger","id":1,"prepTime":20,"qty":1,"item":"burger","price":25}]', 25, 1783393031),
	(6, 1, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":[],"prepTime":20,"price":25,"name":"X-Burger","item":"burger","id":1,"qty":1}]', 25, 1783393279),
	(7, 1, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"price":25,"prepTime":20,"name":"X-Burger","item":"burger","id":1,"qty":1}]', 25, 1783393886),
	(8, 2, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"price":25,"prepTime":20,"name":"X-Burger","item":"burger","id":1,"qty":5}]', 125, 1783393937),
	(9, 1, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"id":1,"price":25,"qty":1,"prepTime":20,"name":"X-Burger","item":"burger"}]', 25, 1783394191),
	(10, 2, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"id":1,"price":25,"qty":5,"prepTime":20,"name":"X-Burger","item":"burger"}]', 125, 1783394305),
	(11, 3, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"id":1,"price":25,"qty":2,"prepTime":20,"name":"X-Burger","item":"burger"},{"recipe":["1x Lata/Garrafa Coca-Cola gelada","1 copo com gelo"],"id":4,"price":8,"qty":5,"prepTime":5,"name":"Coca-Cola","item":"cola"}]', 90, 1783394439),
	(12, 4, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"id":1,"price":25,"qty":1,"prepTime":20,"name":"X-Burger","item":"burger"}]', 25, 1783394700),
	(13, 1, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"item":"burger","prepTime":20,"qty":1,"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"name":"X-Burger","price":25,"id":1}]', 25, 1783395028),
	(14, 2, 1, 4, 'Dentista Dev', 'Dentista Dev', '[{"item":"burger","prepTime":20,"qty":1,"recipe":["1x Pão de Brioche (com gergelim)","1x Hambúrguer de Frango (160g)","2 fatias Queijo Prato","1 porção Maionese Especial","1 un. Alface e Tomate"],"name":"X-Burger","price":25,"id":1}]', 25, 1783395688),
	(15, 1, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"name":"X-Burger","id":1,"item":"burger","prepTime":20,"qty":3,"price":25,"recipe":[{"label":"Pão de Brioche (com gergelim)","qty":1,"item":"rm_pao_brioche"},{"label":"Hambúrguer de Frango (160g)","qty":1,"item":"rm_frango_bife"},{"label":"Queijo Prato (fatia)","qty":2,"item":"rm_queijo_prato"},{"label":"Maionese Especial","qty":1,"item":"rm_maionese"},{"label":"Alface e Tomate","qty":1,"item":"rm_alface_tomate"}]}]', 75, 1783464326),
	(16, 1, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"recipe":[{"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)","qty":1},{"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)","qty":1},{"item":"rm_queijo_prato","label":"Queijo Prato (fatia)","qty":2},{"item":"rm_maionese","label":"Maionese Especial","qty":1},{"item":"rm_alface_tomate","label":"Alface e Tomate","qty":1}],"prepTime":20,"id":1,"item":"burger","name":"X-Burger","qty":1,"price":25}]', 25, 1783465331),
	(17, 3, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"recipe":[],"prepTime":10,"id":6,"item":"rm_milkshake","name":"shake","qty":1,"price":100}]', 100, 1783466507),
	(18, 2, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"recipe":[{"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)","qty":1},{"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)","qty":1},{"item":"rm_queijo_prato","label":"Queijo Prato (fatia)","qty":2},{"item":"rm_maionese","label":"Maionese Especial","qty":1},{"item":"rm_alface_tomate","label":"Alface e Tomate","qty":1}],"prepTime":20,"id":1,"item":"burger","name":"X-Burger","qty":1,"price":25}]', 25, 1783466769),
	(19, 1, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"prepTime":20,"recipe":[{"qty":1,"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)"},{"qty":1,"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)"},{"qty":2,"item":"rm_queijo_prato","label":"Queijo Prato (fatia)"},{"qty":1,"item":"rm_maionese","label":"Maionese Especial"},{"qty":1,"item":"rm_alface_tomate","label":"Alface e Tomate"}],"item":"burger","id":1,"qty":1,"price":25,"name":"X-Burger"}]', 25, 1783469441),
	(20, 2, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"prepTime":20,"recipe":[{"qty":1,"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)"},{"qty":1,"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)"},{"qty":2,"item":"rm_queijo_prato","label":"Queijo Prato (fatia)"},{"qty":1,"item":"rm_maionese","label":"Maionese Especial"},{"qty":1,"item":"rm_alface_tomate","label":"Alface e Tomate"}],"item":"burger","id":1,"qty":1,"price":25,"name":"X-Burger"}]', 25, 1783469652),
	(21, 1, 1, 6, 'Dentista Dev', 'Dentista Dev', '[{"id":1,"recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"name":"X-Burger","price":25,"prepTime":20,"item":"burger","qty":1}]', 25, 1783472414),
	(22, 1, 1, 7, 'Dentista Dev', 'Dentista Dev', '[{"name":"X-Burger","prepTime":20,"id":1,"recipe":[{"qty":1,"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche"},{"qty":1,"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife"},{"qty":2,"label":"Queijo Prato (fatia)","item":"rm_queijo_prato"},{"qty":1,"label":"Maionese Especial","item":"rm_maionese"},{"qty":1,"label":"Alface e Tomate","item":"rm_alface_tomate"}],"qty":5,"price":25,"item":"burger"}]', 113, 1783476869),
	(23, 1, 1, 1, 'Dentista Dev', 'Dentista Dev', '[{"recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"id":1,"item":"burger","name":"X-Burger","price":25,"prepTime":20,"qty":2}]', 50, 1783633714),
	(24, 2, 1, 1, 'Dentista Dev', 'Dentista Dev', '[{"recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"id":1,"item":"burger","name":"X-Burger","price":25,"prepTime":20,"qty":2}]', 50, 1783633857),
	(25, 1, 1, 2, 'Dentista Dev', 'Allors', '[{"price":25,"recipe":[{"qty":1,"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)"},{"qty":1,"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)"},{"qty":2,"item":"rm_queijo_prato","label":"Queijo Prato (fatia)"},{"qty":1,"item":"rm_maionese","label":"Maionese Especial"},{"qty":1,"item":"rm_alface_tomate","label":"Alface e Tomate"}],"name":"X-Burger","prepTime":20,"id":1,"qty":1,"item":"burger"},{"price":8,"recipe":[{"qty":1,"item":"rm_lata_cola","label":"Lata/Garrafa Coca-Cola gelada"},{"qty":1,"item":"rm_gelo","label":"Gelo (copo)"}],"name":"Coca-Cola","prepTime":5,"id":4,"qty":1,"item":"cola"}]', 33, 1783805614),
	(26, 1, 1, 2, 'Dentista Dev', 'Allors', '[{"id":1,"price":25,"name":"X-Burger","recipe":[{"label":"Pão de Brioche (com gergelim)","qty":1,"item":"rm_pao_brioche"},{"label":"Hambúrguer de Frango (160g)","qty":1,"item":"rm_frango_bife"},{"label":"Queijo Prato (fatia)","qty":2,"item":"rm_queijo_prato"},{"label":"Maionese Especial","qty":1,"item":"rm_maionese"},{"label":"Alface e Tomate","qty":1,"item":"rm_alface_tomate"}],"prepTime":20,"qty":1,"item":"burger"}]', 25, 1783806402),
	(27, 1, 1, 2, 'Dentista Dev', 'Cliente (Balcão)', '[{"recipe":[{"qty":1,"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)"},{"qty":1,"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)"},{"qty":2,"item":"rm_queijo_prato","label":"Queijo Prato (fatia)"},{"qty":1,"item":"rm_maionese","label":"Maionese Especial"},{"qty":1,"item":"rm_alface_tomate","label":"Alface e Tomate"}],"name":"X-Burger","prepTime":20,"id":1,"qty":1,"price":25,"item":"burger"}]', 25, 1783808434),
	(28, 2, 1, 2, 'Dentista Dev', 'teste', '[{"recipe":[{"qty":1,"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)"},{"qty":1,"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)"},{"qty":2,"item":"rm_queijo_prato","label":"Queijo Prato (fatia)"},{"qty":1,"item":"rm_maionese","label":"Maionese Especial"},{"qty":1,"item":"rm_alface_tomate","label":"Alface e Tomate"}],"name":"X-Burger","prepTime":20,"id":1,"qty":1,"price":25,"item":"burger"}]', 25, 1783808435),
	(29, 1, 1, 1, 'Dentista Dev', 'Allors', '[{"id":1,"item":"burger","recipe":[{"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche","qty":1},{"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife","qty":1},{"label":"Queijo Prato (fatia)","item":"rm_queijo_prato","qty":2},{"label":"Maionese Especial","item":"rm_maionese","qty":1},{"label":"Alface e Tomate","item":"rm_alface_tomate","qty":1}],"prepTime":20,"qty":1,"name":"X-Burger","price":25}]', 23, 1783812169),
	(30, 1, 1, 1, 'Dentista Dev', 'Thiago', '[{"prepTime":20,"price":25,"id":1,"item":"burger","recipe":[{"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)","qty":1},{"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)","qty":1},{"item":"rm_queijo_prato","label":"Queijo Prato (fatia)","qty":2},{"item":"rm_maionese","label":"Maionese Especial","qty":1},{"item":"rm_alface_tomate","label":"Alface e Tomate","qty":1}],"qty":1,"name":"X-Burger"}]', 25, 1783813927),
	(31, 2, 1, 1, 'Dentista Dev', 'allors2', '[{"prepTime":20,"price":25,"id":1,"item":"burger","recipe":[{"item":"rm_pao_brioche","label":"Pão de Brioche (com gergelim)","qty":1},{"item":"rm_frango_bife","label":"Hambúrguer de Frango (160g)","qty":1},{"item":"rm_queijo_prato","label":"Queijo Prato (fatia)","qty":2},{"item":"rm_maionese","label":"Maionese Especial","qty":1},{"item":"rm_alface_tomate","label":"Alface e Tomate","qty":1}],"qty":1,"name":"X-Burger"}]', 25, 1783814027),
	(32, 1, 1, 9, 'Alors Staff', 'Luigi Atanaghui', '[{"prepTime":20,"price":25,"item":"burger","qty":2,"recipe":[{"qty":1,"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche"},{"qty":1,"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife"},{"qty":2,"label":"Queijo Prato (fatia)","item":"rm_queijo_prato"},{"qty":1,"label":"Maionese Especial","item":"rm_maionese"},{"qty":1,"label":"Alface e Tomate","item":"rm_alface_tomate"}],"id":1,"name":"X-Burger"}]', 45, 1783984704),
	(33, 2, 1, 9, 'Alors Staff', 'Luigi Atanaghui', '[{"prepTime":20,"price":25,"item":"burger","qty":2,"recipe":[{"qty":1,"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche"},{"qty":1,"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife"},{"qty":2,"label":"Queijo Prato (fatia)","item":"rm_queijo_prato"},{"qty":1,"label":"Maionese Especial","item":"rm_maionese"},{"qty":1,"label":"Alface e Tomate","item":"rm_alface_tomate"}],"id":1,"name":"X-Burger"}]', 45, 1783984778),
	(34, 3, 1, 9, 'Alors Staff', 'Luigi Atanaghui', '[{"prepTime":20,"price":25,"item":"burger","qty":2,"recipe":[{"qty":1,"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche"},{"qty":1,"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife"},{"qty":2,"label":"Queijo Prato (fatia)","item":"rm_queijo_prato"},{"qty":1,"label":"Maionese Especial","item":"rm_maionese"},{"qty":1,"label":"Alface e Tomate","item":"rm_alface_tomate"}],"id":1,"name":"X-Burger"}]', 50, 1783985005),
	(35, 4, 1, 9, 'Alors Staff', 'Neide Silva', '[{"prepTime":20,"price":25,"item":"burger","qty":1,"recipe":[{"qty":1,"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche"},{"qty":1,"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife"},{"qty":2,"label":"Queijo Prato (fatia)","item":"rm_queijo_prato"},{"qty":1,"label":"Maionese Especial","item":"rm_maionese"},{"qty":1,"label":"Alface e Tomate","item":"rm_alface_tomate"}],"id":1,"name":"X-Burger"}]', 25, 1783985040),
	(36, 5, 1, 9, 'Alors Staff', 'Luigi Atanaghui', '[{"prepTime":20,"price":25,"item":"burger","qty":2,"recipe":[{"qty":1,"label":"Pão de Brioche (com gergelim)","item":"rm_pao_brioche"},{"qty":1,"label":"Hambúrguer de Frango (160g)","item":"rm_frango_bife"},{"qty":2,"label":"Queijo Prato (fatia)","item":"rm_queijo_prato"},{"qty":1,"label":"Maionese Especial","item":"rm_maionese"},{"qty":1,"label":"Alface e Tomate","item":"rm_alface_tomate"}],"id":1,"name":"X-Burger"}]', 50, 1783985069),
	(37, 6, 1, 9, 'Alors Staff', 'Luigi Atanaghui', '[{"prepTime":5,"price":8,"item":"cola","qty":17,"recipe":[{"qty":1,"label":"Lata/Garrafa Coca-Cola gelada","item":"rm_lata_cola"},{"qty":1,"label":"Gelo (copo)","item":"rm_gelo"}],"id":4,"name":"Coca-Cola"}]', 136, 1783985215);

-- Copiando estrutura para tabela mri_server.rm_restaurant_stocklog
CREATE TABLE IF NOT EXISTS `rm_restaurant_stocklog` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `restaurant_index` int(11) NOT NULL,
  `employee_name` varchar(100) NOT NULL DEFAULT '',
  `item_name` varchar(100) NOT NULL DEFAULT '',
  `action` varchar(10) NOT NULL,
  `qty` int(11) NOT NULL DEFAULT 0,
  `created_at` int(11) NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_restaurant` (`restaurant_index`)
) ENGINE=InnoDB AUTO_INCREMENT=21 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- Copiando dados para a tabela mri_server.rm_restaurant_stocklog: ~18 rows (aproximadamente)
INSERT INTO `rm_restaurant_stocklog` (`id`, `restaurant_index`, `employee_name`, `item_name`, `action`, `qty`, `created_at`) VALUES
	(1, 1, 'Dentista Dev', 'Coca-Cola', 'remove', 1, 1783386238),
	(2, 1, 'Dentista Dev', 'Coca-Cola', 'remove', 1, 1783386273),
	(3, 1, 'Dentista Dev', 'Cheeseburger Duplo', 'remove', 1, 1783386376),
	(4, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783386997),
	(5, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783387225),
	(6, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783387251),
	(7, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783387483),
	(8, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783387500),
	(9, 1, 'Dentista Dev', 'X-Burger', 'add', 1, 1783387518),
	(10, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783388857),
	(11, 1, 'Dentista Dev', 'X-Burger', 'add', 1, 1783464409),
	(12, 1, 'Dentista Dev', 'X-Burger', 'add', 1, 1783464435),
	(13, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783464955),
	(14, 1, 'Dentista Dev', 'X-Burger', 'add', 1, 1783469009),
	(15, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783469091),
	(16, 1, 'Dentista Dev', 'X-Burger', 'add', 100, 1783633617),
	(17, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1783805529),
	(18, 1, 'Alors Staff', 'X-Burger', 'add', 10, 1783985153),
	(19, 1, 'Alors Staff', 'Coca-Cola', 'add', 10, 1783985168),
	(20, 1, 'Dentista Dev', 'X-Burger', 'remove', 1, 1784388367);

/*!40103 SET TIME_ZONE=IFNULL(@OLD_TIME_ZONE, 'system') */;
/*!40101 SET SQL_MODE=IFNULL(@OLD_SQL_MODE, '') */;
/*!40014 SET FOREIGN_KEY_CHECKS=IFNULL(@OLD_FOREIGN_KEY_CHECKS, 1) */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40111 SET SQL_NOTES=IFNULL(@OLD_SQL_NOTES, 1) */;
