-- =====================================================================
-- Hotel Alpheus - Seed (datos ficticios deterministicos)
-- CETYS Universidad - Diseno de Bases de Datos 2026-1, Proyecto Final
-- =====================================================================
-- Cumple lineamiento: >=50 tuplas por tabla.
-- Locale: ~70% Mexico + ~30% internacional.
-- Fecha ancla: 2026-05-15 (queries "ultimo mes/ano" reproducibles entre corridas).
-- Pre-requisito: ejecutar primero sql/01_schema.sql.
--
-- Distribucion de reservaciones (120 total):
--   - 50 completadas (-> estancia + cuenta + factura + pago)
--   - 50 canceladas  (-> cancelacion)
--   - 10 check_in    (estancia activa, vista "huespedes ahora mismo")
--   - 10 futuras     (5 confirmadas + 5 pendientes, vista "proyeccion 7 dias")
--
-- Sesgo de IDs deliberado para alimentar las 30 queries del lineamiento:
--   - id_huesped 1..5  -> 8 completadas + 4 canceladas c/u -> Top clientes,
--                         "mas de 5 reservas" y "mas de 2 cancelaciones".
--   - id_huesped 6..10 -> 2 completadas
--   - id_huesped 11..40-> 1 cancelacion c/u
--   - id_huesped 31..40-> +1 futura
--   - id_huesped 41..50-> 1 check_in (alimentan estancias activas).
--
-- Triggers/procedures aun no existen al ejecutar este seed.
-- Los CHECK constraints y FKs si se validan; tras 03_triggers.sql el
-- estado de la BD sigue siendo coherente con las reglas de negocio.
-- =====================================================================

USE hotel_alpheus;

SET @ANCHOR := DATE '2026-05-15';
SET SESSION cte_max_recursion_depth = 1000;

-- ---------------------------------------------------------------------
-- 1. CATALOGOS
-- ---------------------------------------------------------------------

-- 1.1 categoria_habitacion: 8 tipos base x ~6 variantes (vista, piso, uso) = 50.
--     Las variantes representan diferenciacion real de inventario.
INSERT INTO categoria_habitacion (nombre, descripcion, precio_base) VALUES
 ('Standard Vista Ciudad Bajo',     'Standard 28m2, king, urbana, pisos 1-2',                 1800.00),
 ('Standard Vista Ciudad Alto',     'Standard 28m2, king, urbana, pisos 3-4',                 1950.00),
 ('Standard Vista Jardin',          'Standard 28m2, king, jardin interior',                   1700.00),
 ('Standard Vista Alberca',         'Standard 28m2, king, vista a la alberca',                2000.00),
 ('Standard Vista Estadio',         'Standard 28m2, king, vista El Coloso del Pacifico',      2250.00),
 ('Standard con Cuna',              'Standard 28m2, king + cuna para bebe',                   2050.00),
 ('Doble Vista Ciudad Bajo',        'Doble 32m2, 2 queen, urbana, pisos 1-2',                 2200.00),
 ('Doble Vista Ciudad Alto',        'Doble 32m2, 2 queen, urbana, pisos 3-4',                 2350.00),
 ('Doble Vista Jardin',             'Doble 32m2, 2 queen, jardin interior',                   2100.00),
 ('Doble Vista Alberca',            'Doble 32m2, 2 queen, vista alberca',                     2400.00),
 ('Doble Vista Estadio',            'Doble 32m2, 2 queen, vista estadio',                     2700.00),
 ('Doble Family Plus',              'Doble 36m2, 2 queen + cuna',                             2500.00),
 ('Familiar Vista Ciudad',          'Familiar 42m2, 2 queen + sofa-cama, urbana',             2900.00),
 ('Familiar Vista Estadio',         'Familiar 42m2, 2 queen + sofa-cama, estadio',            3300.00),
 ('Familiar Vista Alberca',         'Familiar 42m2, 2 queen + sofa-cama, alberca',            3100.00),
 ('Familiar Premium',               'Familiar 48m2, 2 queen + sofa, balcon privado',          3600.00),
 ('Familiar Adaptada Accesible',    'Familiar 42m2 con accesibilidad para silla de ruedas',   3000.00),
 ('Familiar Pet-Friendly',          'Familiar 42m2 con paquete mascota',                      3050.00),
 ('Junior Suite Vista Ciudad',      'Junior Suite 50m2, king, jacuzzi, urbana',               4200.00),
 ('Junior Suite Vista Estadio',     'Junior Suite 50m2, king, jacuzzi, estadio',              4600.00),
 ('Junior Suite Vista Alberca',     'Junior Suite 50m2, king, jacuzzi, alberca',              4400.00),
 ('Junior Suite Spa',               'Junior Suite 52m2, king, jacuzzi doble + sauna',         5000.00),
 ('Junior Suite Romantica',         'Junior Suite 50m2, king, decoracion + room service',     4800.00),
 ('Junior Suite Negocios',          'Junior Suite 50m2, king, escritorio + wifi VIP',         4700.00),
 ('Suite Ejecutiva Vista Ciudad',   'Suite Ejecutiva 65m2, king + sala + comedor',            6800.00),
 ('Suite Ejecutiva Vista Estadio',  'Suite Ejecutiva 65m2, king + sala + comedor, estadio',   7400.00),
 ('Suite Ejecutiva Vista Alberca',  'Suite Ejecutiva 65m2, king + sala + comedor, alberca',   7100.00),
 ('Suite Ejecutiva Negocios',       'Suite Ejecutiva 68m2, oficina + impresora + wifi VIP',   7600.00),
 ('Suite Ejecutiva Familiar',       'Suite Ejecutiva 68m2, king + sofa cama doble',           7300.00),
 ('Suite Ejecutiva Spa',            'Suite Ejecutiva 70m2, jacuzzi + sauna privado',          7900.00),
 ('Premier Vista Ciudad',           'Premier 70m2, king, terraza, panoramica urbana',         7500.00),
 ('Premier Vista Estadio',          'Premier 70m2, king, terraza, panoramica estadio',        8200.00),
 ('Premier Vista Alberca',          'Premier 70m2, king, terraza, panoramica alberca',        7800.00),
 ('Premier Romantica',              'Premier 72m2, king, terraza con jacuzzi',                8800.00),
 ('Premier Familiar',               'Premier 75m2, king + sofa cama, terraza',                8500.00),
 ('Premier Spa',                    'Premier 75m2, king, terraza con sauna',                  9000.00),
 ('Suite Presidencial Vista Ciudad','Suite Presidencial 110m2, king + sala + kitchenette',   14000.00),
 ('Suite Presidencial Vista Estadio','Suite Presidencial 110m2, vista estadio',              15500.00),
 ('Suite Presidencial Vista Alberca','Suite Presidencial 110m2, vista alberca',              14500.00),
 ('Suite Presidencial Family',      'Suite Presidencial 115m2, king + 2 sofa cama doble',    15000.00),
 ('Suite Presidencial Spa',         'Suite Presidencial 120m2 con sauna y jacuzzi doble',    16500.00),
 ('Suite Presidencial Negocios',    'Suite Presidencial 115m2 con sala juntas 8 personas',   15800.00),
 ('Penthouse Vista Ciudad',         'Penthouse 180m2, doble nivel, jacuzzi y bar privados',  24000.00),
 ('Penthouse Vista Estadio',        'Penthouse 180m2, doble nivel, vista estadio',           26500.00),
 ('Penthouse Vista Alberca',        'Penthouse 180m2, doble nivel, alberca privada',         25500.00),
 ('Penthouse Spa',                  'Penthouse 200m2, sauna, jacuzzi, gym privado',          28000.00),
 ('Penthouse Familiar',             'Penthouse 200m2, 3 recamaras, sala familiar',           27500.00),
 ('Penthouse Romantico',            'Penthouse 180m2, suite nupcial premium',                26000.00),
 ('Bungalow Jardin',                'Bungalow 65m2, king, terraza propia con jardin',         5500.00),
 ('Cabana Alberca',                 'Cabana 55m2, king, acceso directo a alberca',            5200.00);

-- 1.2 tipo_servicio: 30 internos + 20 externos = 50.
INSERT INTO tipo_servicio (nombre, categoria) VALUES
 ('Spa Masaje','interno'),('Spa Facial','interno'),('Spa Aromaterapia','interno'),
 ('Spa Sauna','interno'),('Spa Jacuzzi','interno'),('Spa Corporal','interno'),
 ('Gimnasio Acceso','interno'),('Gimnasio Clase Funcional','interno'),
 ('Gimnasio Clase Yoga','interno'),('Gimnasio Entrenador Personal','interno'),
 ('Restaurante Principal','interno'),('Restaurante Buffet','interno'),
 ('Restaurante Gourmet','interno'),('Cafeteria Lobby','interno'),
 ('Salon Eventos Pequeno','interno'),('Salon Eventos Mediano','interno'),
 ('Salon Eventos Grande','interno'),('Bar Lobby','interno'),
 ('Bar Alberca','interno'),('Bar Terraza','interno'),
 ('Discoteca','interno'),('Campo de Golf 18 Hoyos','interno'),
 ('Mini Golf','interno'),('Casino General','interno'),
 ('Casino VIP','interno'),('Room Service 24h','interno'),
 ('Lavanderia','interno'),('Alberca Climatizada','interno'),
 ('Kids Club','interno'),('Salon Belleza','interno'),
 ('Tour Estadio Coloso','externo'),('Tour Centro Historico Tepic','externo'),
 ('Tour Playa Sayulita','externo'),('Tour Volcan Ceboruco','externo'),
 ('Tour Cascadas El Salto','externo'),('Tour Aguas Termales Hervores','externo'),
 ('Tour Haciendas Coloniales','externo'),('Tour Pueblos Magicos','externo'),
 ('Tour Islas Marietas','externo'),('Museo Arqueologia Nayarit','externo'),
 ('Museo Arte Tepic','externo'),('Museo Amado Nervo','externo'),
 ('Festival Cultural Tepic','externo'),('Festival Gastronomico','externo'),
 ('Zona Historica Jala','externo'),('Paseo Yate Privado','externo'),
 ('Helitour Tepic','externo'),('Parque Acuatico Splash','externo'),
 ('Traslado Aeropuerto Tepic','externo'),('Traslado Estadio Coloso','externo');

-- 1.3 servicio: 50 servicios, uno por tipo.
INSERT INTO servicio (id_tipo_servicio, nombre_servicio, precio, disponible) VALUES
 ( 1,'Masaje relajante 60min',    1200.00,TRUE), ( 2,'Facial hidratante',         950.00,TRUE),
 ( 3,'Aromaterapia 45min',         850.00,TRUE), ( 4,'Sesion sauna 30min',        350.00,TRUE),
 ( 5,'Jacuzzi privado 45min',      500.00,TRUE), ( 6,'Tratamiento corporal',     1450.00,TRUE),
 ( 7,'Pase diario gimnasio',       200.00,TRUE), ( 8,'Clase funcional grupal',    250.00,TRUE),
 ( 9,'Clase yoga al amanecer',     280.00,TRUE), (10,'Sesion 1-1 entrenador',     900.00,TRUE),
 (11,'Comida 3 tiempos Principal', 650.00,TRUE), (12,'Buffet desayuno ilimitado', 480.00,TRUE),
 (13,'Menu degustacion Gourmet',  1800.00,TRUE), (14,'Cafe + postre Lobby',       180.00,TRUE),
 (15,'Renta salon S (4h)',        3500.00,TRUE), (16,'Renta salon M (4h)',       6500.00,TRUE),
 (17,'Renta salon L (4h)',       12500.00,TRUE), (18,'Cocteleria Lobby',          280.00,TRUE),
 (19,'Cocteleria Alberca',         320.00,TRUE), (20,'Cocteleria Terraza',        350.00,TRUE),
 (21,'Entrada Discoteca + 2',      650.00,TRUE), (22,'Ronda 18 hoyos golf',      2400.00,TRUE),
 (23,'Mini golf 9 hoyos',          250.00,TRUE), (24,'Acceso Casino general',     150.00,TRUE),
 (25,'Acceso Casino VIP',         1500.00,TRUE), (26,'Comida en habitacion 24h',  200.00,TRUE),
 (27,'Lavado por pieza',            80.00,TRUE), (28,'Acceso ilimitado alberca',  100.00,TRUE),
 (29,'Kids club 4h',               400.00,TRUE), (30,'Peinado profesional',       600.00,TRUE),
 (31,'Tour guiado Estadio Coloso', 850.00,TRUE), (32,'Tour Centro Historico',     550.00,TRUE),
 (33,'Tour playa Sayulita 8h',    1800.00,TRUE), (34,'Tour volcan Ceboruco',     1500.00,TRUE),
 (35,'Tour cascadas El Salto',    1200.00,TRUE), (36,'Tour aguas termales',      1400.00,TRUE),
 (37,'Tour haciendas coloniales', 2100.00,TRUE), (38,'Tour pueblos magicos 2d',  4500.00,TRUE),
 (39,'Tour Islas Marietas',       2800.00,TRUE), (40,'Entrada Museo Arqueologia', 180.00,TRUE),
 (41,'Entrada Museo Arte',         150.00,TRUE), (42,'Entrada Museo Amado Nervo', 120.00,TRUE),
 (43,'Acceso Festival Cultural',   250.00,TRUE), (44,'Acceso Festival Gastro',    450.00,TRUE),
 (45,'Tour Zona Historica Jala',   800.00,TRUE), (46,'Paseo Yate 4h',            5500.00,TRUE),
 (47,'Helitour panoramico 20min', 3800.00,TRUE), (48,'Entrada Parque Acuatico',   650.00,TRUE),
 (49,'Traslado ida-vuelta aero',   750.00,TRUE), (50,'Traslado al Estadio',       220.00,TRUE);

-- 1.4 evento_temporada: 50 eventos cubriendo ~3 anos.
INSERT INTO evento_temporada (nombre_evento, fecha_inicio, fecha_fin) VALUES
 ('Semana Santa 2024',                '2024-03-24','2024-03-30'),
 ('Verano 2024',                      '2024-06-15','2024-08-31'),
 ('Dia de la Independencia 2024',     '2024-09-13','2024-09-17'),
 ('Dia de la Revolucion 2024',        '2024-11-18','2024-11-21'),
 ('Dia de Muertos 2024',              '2024-10-30','2024-11-03'),
 ('Accion de Gracias 2024',           '2024-11-25','2024-12-01'),
 ('Navidad 2024',                     '2024-12-20','2024-12-27'),
 ('Ano Nuevo 2024-25',                '2024-12-28','2025-01-05'),
 ('San Valentin 2025',                '2025-02-12','2025-02-16'),
 ('Carnaval Tepic 2025',              '2025-02-22','2025-03-04'),
 ('Semana Santa 2025',                '2025-04-13','2025-04-20'),
 ('Dia de la Madre 2025',             '2025-05-08','2025-05-12'),
 ('Liga MX Beisbol Primavera 2025',   '2025-03-15','2025-06-15'),
 ('Festival Gastronomico 2025',       '2025-05-20','2025-05-28'),
 ('Verano 2025',                      '2025-06-15','2025-08-31'),
 ('Feria Tepic 2025',                 '2025-08-01','2025-08-25'),
 ('Liga MX Beisbol Verano 2025',      '2025-06-16','2025-09-15'),
 ('Dia de la Independencia 2025',     '2025-09-13','2025-09-17'),
 ('Playoffs Beisbol 2025',            '2025-09-20','2025-10-15'),
 ('Festival Cultural Tepic 2025',     '2025-10-05','2025-10-15'),
 ('Dia de Muertos 2025',              '2025-10-30','2025-11-03'),
 ('Dia de la Revolucion 2025',        '2025-11-18','2025-11-21'),
 ('Accion de Gracias 2025',           '2025-11-24','2025-11-30'),
 ('Navidad 2025',                     '2025-12-20','2025-12-27'),
 ('Ano Nuevo 2025-26',                '2025-12-28','2026-01-05'),
 ('San Valentin 2026',                '2026-02-11','2026-02-16'),
 ('Carnaval Tepic 2026',              '2026-02-13','2026-02-21'),
 ('Semana Santa 2026',                '2026-03-29','2026-04-05'),
 ('Dia de la Madre 2026',             '2026-05-07','2026-05-11'),
 ('Festival Gastronomico 2026',       '2026-05-19','2026-05-27'),
 ('Liga MX Beisbol Primavera 2026',   '2026-03-15','2026-06-15'),
 ('Verano 2026',                      '2026-06-15','2026-08-31'),
 ('Feria Tepic 2026',                 '2026-08-01','2026-08-25'),
 ('Liga MX Beisbol Verano 2026',      '2026-06-16','2026-09-15'),
 ('Dia de la Independencia 2026',     '2026-09-13','2026-09-17'),
 ('Festival Cultural Tepic 2026',     '2026-10-05','2026-10-15'),
 ('Dia de Muertos 2026',              '2026-10-30','2026-11-03'),
 ('Playoffs Beisbol 2026',            '2026-09-20','2026-10-15'),
 ('Accion de Gracias 2026',           '2026-11-23','2026-11-29'),
 ('Dia de la Revolucion 2026',        '2026-11-18','2026-11-21'),
 ('Navidad 2026',                     '2026-12-20','2026-12-27'),
 ('Spring Break Internacional 2025',  '2025-03-08','2025-03-22'),
 ('Spring Break Internacional 2026',  '2026-03-07','2026-03-21'),
 ('Boda Nacional Temporada Alta 2025','2025-04-15','2025-08-15'),
 ('Boda Nacional Temporada Alta 2026','2026-04-15','2026-08-15'),
 ('Congresos Internacionales 2024',   '2024-09-01','2024-11-30'),
 ('Congresos Internacionales 2025',   '2025-09-01','2025-11-30'),
 ('Maratones Nayarit 2025',           '2025-10-20','2025-10-26'),
 ('Maratones Nayarit 2026',           '2026-10-19','2026-10-25'),
 ('Convencion Beisbol Mexicano 2026', '2026-07-10','2026-07-25');

-- 1.5 paquete_promocional: 50 paquetes, uno por evento.
INSERT INTO paquete_promocional (id_evento, descripcion, precio, inicio_validez, fin_validez) VALUES
 ( 1,'Paquete Semana Santa 2024 - 3 noches + spa',                 8500.00,'2024-03-24','2024-03-30'),
 ( 2,'Paquete Verano 2024 - 5 noches + alberca + tour',           14500.00,'2024-06-15','2024-08-31'),
 ( 3,'Paquete Patrio 2024 - 3 noches + cena gala',                 9800.00,'2024-09-13','2024-09-17'),
 ( 4,'Paquete Revolucion 2024 - 2 noches + tour historico',        5200.00,'2024-11-18','2024-11-21'),
 ( 5,'Paquete Dia Muertos 2024 - 2 noches + tour panteon',         5800.00,'2024-10-30','2024-11-03'),
 ( 6,'Paquete Thanksgiving 2024 - 3 noches + cena pavo',           9000.00,'2024-11-25','2024-12-01'),
 ( 7,'Paquete Navidad 2024 - 5 noches + cena',                    16500.00,'2024-12-20','2024-12-27'),
 ( 8,'Paquete Ano Nuevo 24-25 - 5 noches + brindis premium',      19500.00,'2024-12-28','2025-01-05'),
 ( 9,'Paquete San Valentin 2025 - 2 noches + cena romantica',      7800.00,'2025-02-12','2025-02-16'),
 (10,'Paquete Carnaval 2025 - 4 noches + tour carnaval',          11500.00,'2025-02-22','2025-03-04'),
 (11,'Paquete Semana Santa 2025 - 4 noches + alberca + buffet',   12500.00,'2025-04-13','2025-04-20'),
 (12,'Paquete Mama 2025 - 2 noches + spa madre e hija',            6800.00,'2025-05-08','2025-05-12'),
 (13,'Paquete Beisbol Primavera 2025 - 3 noches + entradas',      10500.00,'2025-03-15','2025-06-15'),
 (14,'Paquete Gastronomico 2025 - 3 noches + degustacion',        10800.00,'2025-05-20','2025-05-28'),
 (15,'Paquete Verano 2025 - 5 noches + tour playa',               15800.00,'2025-06-15','2025-08-31'),
 (16,'Paquete Feria Tepic 2025 - 3 noches + entradas feria',       9500.00,'2025-08-01','2025-08-25'),
 (17,'Paquete Beisbol Verano 2025 - 5 noches + entradas',         14800.00,'2025-06-16','2025-09-15'),
 (18,'Paquete Patrio 2025 - 3 noches + cena gala',                10200.00,'2025-09-13','2025-09-17'),
 (19,'Paquete Playoffs 2025 - 3 noches + entradas playoff',       12800.00,'2025-09-20','2025-10-15'),
 (20,'Paquete Festival Cultural 2025 - 3 noches + pase festival',  8800.00,'2025-10-05','2025-10-15'),
 (21,'Paquete Dia Muertos 2025 - 3 noches + tour panteon',         6800.00,'2025-10-30','2025-11-03'),
 (22,'Paquete Revolucion 2025 - 2 noches + tour historico',        5500.00,'2025-11-18','2025-11-21'),
 (23,'Paquete Thanksgiving 2025 - 3 noches + cena pavo',           9500.00,'2025-11-24','2025-11-30'),
 (24,'Paquete Navidad 2025 - 5 noches + cena',                    17500.00,'2025-12-20','2025-12-27'),
 (25,'Paquete Ano Nuevo 25-26 - 5 noches + brindis',              20500.00,'2025-12-28','2026-01-05'),
 (26,'Paquete San Valentin 2026 - 2 noches + cena',                8200.00,'2026-02-11','2026-02-16'),
 (27,'Paquete Carnaval 2026 - 4 noches + tour',                   12200.00,'2026-02-13','2026-02-21'),
 (28,'Paquete Semana Santa 2026 - 4 noches + buffet',             13500.00,'2026-03-29','2026-04-05'),
 (29,'Paquete Mama 2026 - 2 noches + spa',                         7200.00,'2026-05-07','2026-05-11'),
 (30,'Paquete Gastronomico 2026 - 3 noches + degustacion',        11500.00,'2026-05-19','2026-05-27'),
 (31,'Paquete Beisbol Primavera 2026 - 3 noches + entradas',      11200.00,'2026-03-15','2026-06-15'),
 (32,'Paquete Verano 2026 - 5 noches + tour playa',               16500.00,'2026-06-15','2026-08-31'),
 (33,'Paquete Feria Tepic 2026 - 3 noches + entradas',            10200.00,'2026-08-01','2026-08-25'),
 (34,'Paquete Beisbol Verano 2026 - 5 noches + entradas',         15500.00,'2026-06-16','2026-09-15'),
 (35,'Paquete Patrio 2026 - 3 noches + cena gala',                10800.00,'2026-09-13','2026-09-17'),
 (36,'Paquete Festival Cultural 2026 - 3 noches + pase',           9500.00,'2026-10-05','2026-10-15'),
 (37,'Paquete Dia Muertos 2026 - 3 noches + tour',                 7500.00,'2026-10-30','2026-11-03'),
 (38,'Paquete Playoffs 2026 - 3 noches + entradas',               13500.00,'2026-09-20','2026-10-15'),
 (39,'Paquete Thanksgiving 2026 - 3 noches + cena',                9800.00,'2026-11-23','2026-11-29'),
 (40,'Paquete Revolucion 2026 - 2 noches + tour',                  5800.00,'2026-11-18','2026-11-21'),
 (41,'Paquete Navidad 2026 - 5 noches + cena',                    18500.00,'2026-12-20','2026-12-27'),
 (42,'Paquete Spring Break 25 - 5 noches all inclusive',          22500.00,'2025-03-08','2025-03-22'),
 (43,'Paquete Spring Break 26 - 5 noches all inclusive',          23500.00,'2026-03-07','2026-03-21'),
 (44,'Paquete Boda 25 - 3 noches paquete novios',                 14800.00,'2025-04-15','2025-08-15'),
 (45,'Paquete Boda 26 - 3 noches paquete novios',                 15800.00,'2026-04-15','2026-08-15'),
 (46,'Paquete Congresos 24 - 4 noches sala juntas',               12500.00,'2024-09-01','2024-11-30'),
 (47,'Paquete Congresos 25 - 4 noches sala juntas',               13500.00,'2025-09-01','2025-11-30'),
 (48,'Paquete Maraton 25 - 2 noches + numero corredor',            6500.00,'2025-10-20','2025-10-26'),
 (49,'Paquete Maraton 26 - 2 noches + numero corredor',            6800.00,'2026-10-19','2026-10-25'),
 (50,'Paquete Convencion Beisbol 26 - 5 noches + entradas',       18500.00,'2026-07-10','2026-07-25');

-- 1.6 detalle_paquete_promocional: 50 vinculaciones paquete-servicio.
INSERT INTO detalle_paquete_promocional (id_paquete_promocional, id_servicio, cantidad_incluida) VALUES
 ( 1, 1,2.00),( 2,28,5.00),( 3,11,3.00),( 4,32,1.00),( 5,32,1.00),
 ( 6,11,3.00),( 7,13,1.00),( 8,18,2.00),( 9,13,1.00),(10,32,1.00),
 (11,12,4.00),(12, 2,2.00),(13,31,1.00),(14,13,1.00),(15,33,1.00),
 (16,44,1.00),(17,31,1.00),(18,11,3.00),(19,31,1.00),(20,43,1.00),
 (21,32,1.00),(22,32,1.00),(23,11,3.00),(24,13,1.00),(25,18,2.00),
 (26,13,1.00),(27,32,1.00),(28,12,4.00),(29, 2,2.00),(30,13,1.00),
 (31,31,1.00),(32,33,1.00),(33,44,1.00),(34,31,1.00),(35,11,3.00),
 (36,43,1.00),(37,32,1.00),(38,31,1.00),(39,11,3.00),(40,32,1.00),
 (41,13,1.00),(42,28,5.00),(43,28,5.00),(44,13,1.00),(45,13,1.00),
 (46,15,1.00),(47,15,1.00),(48,10,1.00),(49,10,1.00),(50,31,1.00);

-- ---------------------------------------------------------------------
-- 2. MAESTROS (derivados con CTE recursiva para mantener compacto)
-- ---------------------------------------------------------------------

-- 2.1 empleado: 50 con departamentos, roles, salarios y bonos variados.
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO empleado (nombres, apellidos, rol, telefono, salario, bono, activo, departamento)
SELECT
  ELT(((n-1) % 20) + 1,
      'Carlos','Maria','Juan','Sofia','Luis','Laura','Miguel','Patricia','Roberto','Adriana',
      'Eduardo','Elena','Alejandro','Carmen','Ricardo','Lucia','Fernando','Isabel','Daniel','Veronica'),
  ELT(((n-1) % 20) + 1,
      'Garcia','Hernandez','Lopez','Martinez','Gonzalez','Rodriguez','Perez','Sanchez','Ramirez','Cruz',
      'Flores','Gomez','Morales','Vazquez','Reyes','Jimenez','Diaz','Aguilar','Torres','Mendoza'),
  ELT(((n-1) % 15) + 1,
      'gerente_general','gerente_recepcion','gerente_finanzas','jefe_housekeeping','recepcionista',
      'cajero','concierge','botones','chef','mesero','bartender','masajista','instructor_gym',
      'mantenimiento','seguridad'),
  CONCAT('311-555-', LPAD((n*97) % 10000, 4, '0')),
  CASE
    WHEN n <=  5 THEN 60000 + n*5000
    WHEN n <= 15 THEN 35000 + n*800
    WHEN n <= 30 THEN 18000 + n*300
    ELSE              10000 + n*150
  END,
  CASE WHEN n % 4 = 0 THEN 2500.00 WHEN n % 7 = 0 THEN 1500.00 ELSE 0.00 END,
  CASE WHEN n % 17 = 0 THEN FALSE ELSE TRUE END,
  ELT(((n-1) % 10) + 1,
      'gerencia','recepcion','finanzas','housekeeping','restaurante',
      'spa','gimnasio','mantenimiento','seguridad','entretenimiento')
FROM seq;

-- 2.2 usuario: 50 usuarios del sistema con roles distribuidos.
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO usuario (email, password, rol)
SELECT
  CONCAT('user', LPAD(n, 3, '0'), '@hotelalpheus.com'),
  -- bcrypt-like placeholder; en produccion debe ser hash real.
  CONCAT('$2b$12$placeholder', LPAD(n, 3, '0'), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX'),
  ELT(((n-1) % 5) + 1, 'admin','recepcion','finanzas','gerencia','reportes')
FROM seq;

-- 2.3 huesped: 50 huespedes (todos seran tambien facturadores 1:1).
--     70% MX, 30% internacional.
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO huesped (nombres, apellidos, fecha_nacimiento, email, pais_origen, sexo)
SELECT
  ELT(((n*7) % 25) + 1,
      'Carlos Eduardo','Maria Fernanda','Juan Pablo','Sofia Isabel','Luis Antonio',
      'Laura Patricia','Miguel Angel','Patricia Elena','Roberto Carlos','Adriana Lucia',
      'Eduardo Javier','Elena Veronica','Alejandro Daniel','Carmen Beatriz','Ricardo Andres',
      'Lucia Margarita','Fernando Ivan','Isabel Cristina','Daniel Esteban','Veronica Paola',
      'John','Mary','Robert','Emma','Michael'),
  ELT(((n*11) % 25) + 1,
      'Garcia Lopez','Hernandez Cruz','Lopez Martinez','Martinez Reyes','Gonzalez Diaz',
      'Rodriguez Flores','Perez Aguilar','Sanchez Torres','Ramirez Mendoza','Cruz Vega',
      'Flores Castaneda','Gomez Ramos','Morales Salazar','Vazquez Castro','Reyes Aparicio',
      'Jimenez Pena','Diaz Olvera','Aguilar Cervantes','Torres Bautista','Mendoza Ruiz',
      'Smith','Johnson','Williams','Brown','Davis'),
  DATE_SUB(DATE '1990-01-01', INTERVAL ((n*73) % 14600) DAY),
  CONCAT('huesped', LPAD(n, 3, '0'), '@correo.com'),
  ELT(((n*13) % 15) + 1,
      'CDMX','Guadalajara','Monterrey','Tijuana','Cancun',
      'Puebla','Merida','Leon','Queretaro','Hermosillo',
      'Madrid, ES','Buenos Aires, AR','Bogota, CO','Toronto, CA','Los Angeles, US'),
  CASE WHEN n % 2 = 0 THEN 'F' ELSE 'M' END
FROM seq;

-- 2.4 huesped_facturador: 50, uno por huesped. RFC pseudo-coherente.
INSERT INTO huesped_facturador (id_huesped, direccion, telefono_casa, telefono_celular, email, rfc, procedencia, numero_reservas)
SELECT
  h.id_huesped,
  CONCAT('Av. Reforma ',
         100 + ((h.id_huesped * 7) % 900),
         ', Col. ',
         ELT(((h.id_huesped-1) % 8) + 1,
             'Centro','Reforma','Las Aguilas','Lomas','Polanco','Jardines','Universidad','Bellavista')),
  CONCAT('311-700-', LPAD((h.id_huesped * 113) % 10000, 4, '0')),
  CONCAT('311-800-', LPAD((h.id_huesped * 131) % 10000, 4, '0')),
  CONCAT('facturador', LPAD(h.id_huesped, 3, '0'), '@factura.com'),
  -- RFC: 4 letras (2 apellido + 2 nombre) + YYMMDD + 3 chars deterministicos.
  CONCAT(
    UPPER(LEFT(REPLACE(h.apellidos, ' ', ''), 2)),
    UPPER(LEFT(REPLACE(h.nombres,   ' ', ''), 2)),
    DATE_FORMAT(h.fecha_nacimiento, '%y%m%d'),
    SUBSTRING('ABCDEFGHIJKLMNOPQRSTUVWXYZ', ((h.id_huesped *  3) % 26) + 1, 1),
    SUBSTRING('ABCDEFGHIJKLMNOPQRSTUVWXYZ', ((h.id_huesped *  7) % 26) + 1, 1),
    CAST(h.id_huesped % 10 AS CHAR)
  ),
  h.pais_origen,
  0
FROM huesped h
ORDER BY h.id_huesped;

-- 2.5 cliente_vip: 50, todos los facturadores entran al programa (lineamiento 2d).
INSERT INTO cliente_vip (id_huesped_facturador, nivel_vip, puntos_acumulados, contador_reservas, fecha_registro)
SELECT
  hf.id_huesped_facturador,
  -- ids 1..5 son los clientes "mas reservadores"; les damos niveles altos.
  CASE
    WHEN hf.id_huesped_facturador <=  5 THEN 'platino'
    WHEN hf.id_huesped_facturador <= 10 THEN 'oro'
    WHEN hf.id_huesped_facturador <= 25 THEN 'plata'
    ELSE 'bronce'
  END,
  (hf.id_huesped_facturador * 137) % 5000,
  0,
  DATE_SUB(@ANCHOR, INTERVAL ((hf.id_huesped_facturador * 11) % 540) DAY)
FROM huesped_facturador hf
ORDER BY hf.id_huesped_facturador;

-- 2.6 habitacion: 50, una por categoria. Numeracion piso-secuencia.
INSERT INTO habitacion (id_categoria, numero_habitacion, piso, precio, estado)
SELECT
  c.id_categoria,
  CONCAT(((c.id_categoria - 1) DIV 10) + 1, LPAD(((c.id_categoria - 1) % 10) + 1, 2, '0')),
  ((c.id_categoria - 1) DIV 10) + 1,
  c.precio_base,
  'disponible'
FROM categoria_habitacion c
ORDER BY c.id_categoria;

-- 2.7 bono_empleado: 50, uno por empleado, fechas distribuidas en 18 meses pasados.
INSERT INTO bono_empleado (id_empleado, monto, fecha_hora, motivo)
SELECT
  e.id_empleado,
  500.00 + ((e.id_empleado * 137) % 4500),
  TIMESTAMP(DATE_SUB(@ANCHOR, INTERVAL ((e.id_empleado * 11) % 540) DAY), '14:30:00'),
  ELT(((e.id_empleado - 1) % 10) + 1,
      'Cumplimiento mensual',
      'Excelencia en servicio',
      'Cero quejas en trimestre',
      'Felicitacion directa de cliente',
      'Ventas arriba de meta',
      'Capacitacion completada',
      'Aniversario laboral',
      'Reduccion de errores operativos',
      'Recomendacion de gerencia',
      'Trabajo en equipo destacado')
FROM empleado e
ORDER BY e.id_empleado;

-- ---------------------------------------------------------------------
-- 3. RESERVACIONES (120 en 4 bloques con sesgo intencional)
-- ---------------------------------------------------------------------

-- 3.1.A: 50 COMPLETADAS. Ids 1..5 acumulan 8 c/u (top clientes), 6..10 acumulan 2 c/u.
--        Fechas: ANCHOR - {41..580} dias. Noches: 1..7 (((n*3) % 7) + 1, no n*7 que siempre da 1).
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO reservacion (id_huesped, id_huesped_facturador, id_usuario, fecha_inicio, fecha_salida, estado, metodo, subtotal, total)
SELECT
  CASE WHEN n <= 40 THEN ((n - 1) DIV 8) + 1 ELSE ((n - 41) DIV 2) + 6 END,
  CASE WHEN n <= 40 THEN ((n - 1) DIV 8) + 1 ELSE ((n - 41) DIV 2) + 6 END,
  ((n - 1) % 50) + 1,
  DATE_SUB(@ANCHOR, INTERVAL (n * 11 + 30) DAY),
  DATE_ADD(DATE_SUB(@ANCHOR, INTERVAL (n * 11 + 30) DAY),
           INTERVAL ((n * 3) % 7 + 1) DAY),
  'completada',
  ELT(((n - 1) % 3) + 1, 'internet','telefono','presencial'),
  0.00, 0.00
FROM seq;

-- 3.1.B: 50 CANCELADAS. Ids 1..5 con 4 c/u (alimentan query "mas de 2 cancelaciones").
--        Ids 11..40 con 1 c/u (cobertura amplia).
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO reservacion (id_huesped, id_huesped_facturador, id_usuario, fecha_inicio, fecha_salida, estado, metodo, subtotal, total)
SELECT
  CASE WHEN n <= 20 THEN ((n - 1) DIV 4) + 1 ELSE (n - 21) + 11 END,
  CASE WHEN n <= 20 THEN ((n - 1) DIV 4) + 1 ELSE (n - 21) + 11 END,
  ((n * 3 - 1) % 50) + 1,
  DATE_SUB(@ANCHOR, INTERVAL (n * 9 + 15) DAY),
  DATE_ADD(DATE_SUB(@ANCHOR, INTERVAL (n * 9 + 15) DAY),
           INTERVAL ((n * 5) % 7 + 1) DAY),
  'cancelada',
  ELT(((n - 1) % 3) + 1, 'internet','telefono','presencial'),
  0.00, 0.00
FROM seq;

-- 3.1.C: 10 CHECK_IN (huespedes hospedados hoy). Ids 41..50.
--        check-in en ANCHOR-{0..9}, salida en ANCHOR+{2..11}.
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 10)
INSERT INTO reservacion (id_huesped, id_huesped_facturador, id_usuario, fecha_inicio, fecha_salida, estado, metodo, subtotal, total)
SELECT
  n + 40, n + 40,
  ((n * 7 - 1) % 50) + 1,
  DATE_SUB(@ANCHOR, INTERVAL (n - 1) DAY),
  DATE_ADD(@ANCHOR, INTERVAL (n + 1) DAY),
  'check_in',
  ELT(((n - 1) % 3) + 1, 'internet','telefono','presencial'),
  0.00, 0.00
FROM seq;

-- 3.1.D: 10 FUTURAS (5 confirmadas + 5 pendientes). Ids 31..40.
--        Inicio en ANCHOR+{12..75}, 1..5 noches.
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 10)
INSERT INTO reservacion (id_huesped, id_huesped_facturador, id_usuario, fecha_inicio, fecha_salida, estado, metodo, subtotal, total)
SELECT
  n + 30, n + 30,
  ((n * 11 - 1) % 50) + 1,
  DATE_ADD(@ANCHOR, INTERVAL (n * 7 + 5) DAY),
  DATE_ADD(@ANCHOR, INTERVAL (n * 7 + 5 + (n % 5) + 1) DAY),
  IF(n <= 5, 'confirmada', 'pendiente'),
  ELT(((n - 1) % 3) + 1, 'internet','telefono','presencial'),
  0.00, 0.00
FROM seq;

-- 3.2 reservacion_habitacion: 1 habitacion por reservacion (120 filas).
--     habitacion rotando entre las 50, tarifa_por_noche derivada del precio base.
INSERT INTO reservacion_habitacion
  (id_reservacion, id_habitacion, tarifa_por_noche, noches, cantidad_habitaciones, subtotal)
SELECT
  r.id_reservacion,
  ((r.id_reservacion * 7) % 50) + 1 AS id_habitacion,
  h.precio AS tarifa_por_noche,
  DATEDIFF(r.fecha_salida, r.fecha_inicio) AS noches,
  1,
  h.precio * DATEDIFF(r.fecha_salida, r.fecha_inicio) AS subtotal
FROM reservacion r
JOIN habitacion h ON h.id_habitacion = ((r.id_reservacion * 7) % 50) + 1;

-- 3.3 estancia: 60 (50 completadas + 10 check_in actuales).
--     Check-in real proxima a 15:00, checkout programado a 12:00.
INSERT INTO estancia
  (id_reservacion, id_empleado, id_habitacion, fecha_hora_checkin, fecha_hora_checkout_programado, fecha_hora_checkout_real)
SELECT
  r.id_reservacion,
  ((r.id_reservacion * 13) % 50) + 1,
  rh.id_habitacion,
  TIMESTAMP(r.fecha_inicio, '15:00:00'),
  TIMESTAMP(r.fecha_salida, '12:00:00'),
  CASE
    WHEN r.estado = 'completada' THEN TIMESTAMP(r.fecha_salida, '11:45:00')
    ELSE NULL
  END
FROM reservacion r
JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
WHERE r.estado IN ('completada','check_in');

-- ---------------------------------------------------------------------
-- 4. CUENTA, FACTURA, PAGO, CANCELACION
-- ---------------------------------------------------------------------

-- 4.1 cuenta: una por reservacion con estancia (completada o check_in) = 60.
INSERT INTO cuenta (id_reservacion, fecha_apertura, fecha_cierre, subtotal, total)
SELECT
  r.id_reservacion,
  r.fecha_inicio,
  CASE WHEN r.estado = 'completada' THEN r.fecha_salida ELSE NULL END,
  0.00, 0.00
FROM reservacion r
WHERE r.estado IN ('completada','check_in');

-- 4.2 detalle_cuenta: 3 lineas por cuenta (habitacion + 2 cargos extra) = 180.
--     Linea 1: cargo de habitacion (subtotal de reservacion_habitacion).
INSERT INTO detalle_cuenta (id_cuenta, tipo, descripcion, cantidad, precio_unitario, descuento, impuesto, importe)
SELECT
  c.id_cuenta,
  'habitacion',
  CONCAT('Hospedaje habitacion ', h.numero_habitacion, ' x ', rh.noches, ' noches'),
  rh.noches,
  rh.tarifa_por_noche,
  0.00,
  ROUND(rh.subtotal * 0.16, 2),
  rh.subtotal + ROUND(rh.subtotal * 0.16, 2)
FROM cuenta c
JOIN reservacion_habitacion rh ON rh.id_reservacion = c.id_reservacion
JOIN habitacion h ON h.id_habitacion = rh.id_habitacion;

-- Linea 2: cargo por servicio (varia por cuenta).
INSERT INTO detalle_cuenta (id_cuenta, tipo, descripcion, cantidad, precio_unitario, descuento, impuesto, importe)
SELECT
  c.id_cuenta,
  'servicio',
  CONCAT('Servicio ', s.nombre_servicio),
  CASE WHEN c.id_cuenta % 3 = 0 THEN 2 ELSE 1 END,
  s.precio,
  0.00,
  ROUND(s.precio * (CASE WHEN c.id_cuenta % 3 = 0 THEN 2 ELSE 1 END) * 0.16, 2),
  s.precio * (CASE WHEN c.id_cuenta % 3 = 0 THEN 2 ELSE 1 END)
   + ROUND(s.precio * (CASE WHEN c.id_cuenta % 3 = 0 THEN 2 ELSE 1 END) * 0.16, 2)
FROM cuenta c
JOIN servicio s ON s.id_servicio = ((c.id_cuenta * 7) % 50) + 1;

-- Linea 3: ajuste/descuento promocional (importe pequeno).
INSERT INTO detalle_cuenta (id_cuenta, tipo, descripcion, cantidad, precio_unitario, descuento, impuesto, importe)
SELECT
  c.id_cuenta,
  'ajuste',
  'Cargo amenidades adicionales',
  1,
  150.00 + ((c.id_cuenta * 11) % 350),
  CASE WHEN c.id_cuenta % 5 = 0 THEN 50.00 ELSE 0.00 END,
  ROUND((150.00 + ((c.id_cuenta * 11) % 350)) * 0.16, 2),
  (150.00 + ((c.id_cuenta * 11) % 350))
   - (CASE WHEN c.id_cuenta % 5 = 0 THEN 50.00 ELSE 0.00 END)
   + ROUND((150.00 + ((c.id_cuenta * 11) % 350)) * 0.16, 2)
FROM cuenta c;

-- 4.3 factura: 50, una por reservacion completada.
--     Mayoria pagadas; algunas pendientes/vencidas para alimentar query 22.
INSERT INTO factura (id_cuenta, id_huesped_facturador, id_empleado, fecha_emision, subtotal, impuestos, total, estado_factura)
SELECT
  c.id_cuenta,
  r.id_huesped_facturador,
  ((r.id_reservacion * 17) % 50) + 1,
  r.fecha_salida,
  0.00, 0.00, 0.00,
  CASE
    WHEN r.id_reservacion % 13 = 0 THEN 'vencida'
    WHEN r.id_reservacion % 11 = 0 THEN 'pendiente'
    ELSE 'pagada'
  END
FROM cuenta c
JOIN reservacion r ON r.id_reservacion = c.id_reservacion
WHERE r.estado = 'completada';

-- 4.4 pago: 50, uno por factura pagada/vencida; las pendientes se quedan sin pago.
INSERT INTO pago (id_factura, fecha_pago, monto, metodo_pago, referencia, estado)
SELECT
  f.id_factura,
  CASE
    WHEN f.estado_factura = 'pagada'  THEN f.fecha_emision
    WHEN f.estado_factura = 'vencida' THEN DATE_ADD(f.fecha_emision, INTERVAL 45 DAY)
    ELSE f.fecha_emision
  END,
  -- monto se reconcilia en seccion 6. Por ahora ponemos un placeholder positivo.
  1.00,
  ELT(((f.id_factura - 1) % 5) + 1, 'efectivo','tarjeta_credito','tarjeta_debito','transferencia','paypal'),
  CONCAT('REF-', LPAD(f.id_factura, 6, '0')),
  CASE
    WHEN f.estado_factura = 'pendiente' THEN 'pendiente'
    WHEN f.estado_factura = 'vencida'   THEN 'reembolsado'
    ELSE 'completado'
  END
FROM factura f;

-- 4.5 cancelacion: 50, una por reservacion cancelada.
--     Penalizacion del 55% si la cancelacion fue tarde (lineamiento 2j).
--     Aqui asumimos 60% son tardias para datos variados.
INSERT INTO cancelacion (id_reservacion, id_usuario, motivo, penalizacion, fecha_cancelacion)
SELECT
  r.id_reservacion,
  ((r.id_reservacion * 19) % 50) + 1,
  ELT(((r.id_reservacion - 1) % 8) + 1,
      'Cambio de planes del cliente',
      'Emergencia familiar',
      'Vuelo cancelado',
      'Cambio de hotel',
      'Insatisfaccion con condiciones',
      'Doble reservacion accidental',
      'Motivos personales no especificados',
      'Cliente cancelo por enfermedad'),
  CASE WHEN r.id_reservacion % 5 IN (0,1,2) THEN ROUND(rh.subtotal * 0.55, 2) ELSE 0.00 END,
  TIMESTAMP(DATE_SUB(r.fecha_inicio, INTERVAL ((r.id_reservacion * 3) % 10) DAY), '10:00:00')
FROM reservacion r
JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
WHERE r.estado = 'cancelada';

-- ---------------------------------------------------------------------
-- 5. CONSUMOS, BITACORA, CALIDAD
-- ---------------------------------------------------------------------

-- 5.1 consumo_servicio: 100 consumos (2 por estancia completada).
--     Fechas dentro del rango de la estancia.
INSERT INTO consumo_servicio (id_reservacion, id_huesped, id_servicio, id_empleado, cantidad, precio_unitario, fecha_hora)
SELECT
  r.id_reservacion,
  r.id_huesped,
  ((r.id_reservacion * 3) % 50) + 1,
  ((r.id_reservacion * 23) % 50) + 1,
  1 + ((r.id_reservacion * 5) % 3),
  s.precio,
  TIMESTAMP(DATE_ADD(r.fecha_inicio, INTERVAL 1 DAY), '13:00:00')
FROM reservacion r
JOIN servicio s ON s.id_servicio = ((r.id_reservacion * 3) % 50) + 1
WHERE r.estado IN ('completada','check_in');

-- Segundo consumo por estancia (servicio distinto).
INSERT INTO consumo_servicio (id_reservacion, id_huesped, id_servicio, id_empleado, cantidad, precio_unitario, fecha_hora)
SELECT
  r.id_reservacion,
  r.id_huesped,
  ((r.id_reservacion * 13) % 50) + 1,
  ((r.id_reservacion * 29) % 50) + 1,
  1,
  s.precio,
  TIMESTAMP(DATE_ADD(r.fecha_inicio, INTERVAL GREATEST(2, DATEDIFF(r.fecha_salida, r.fecha_inicio) - 1) DAY), '20:30:00')
FROM reservacion r
JOIN servicio s ON s.id_servicio = ((r.id_reservacion * 13) % 50) + 1
WHERE r.estado IN ('completada','check_in');

-- 5.2 bitacora_habitacion: 2 entradas por estancia (check-in y check-out)
--     = 120 entradas. Las del check_in actual solo tienen evento de ingreso.
INSERT INTO bitacora_habitacion (id_habitacion, id_empleado, id_reservacion, estado_anterior, estado_nuevo, fecha_hora)
SELECT
  e.id_habitacion, e.id_empleado, e.id_reservacion,
  'disponible', 'ocupada', e.fecha_hora_checkin
FROM estancia e;

INSERT INTO bitacora_habitacion (id_habitacion, id_empleado, id_reservacion, estado_anterior, estado_nuevo, fecha_hora)
SELECT
  e.id_habitacion, e.id_empleado, e.id_reservacion,
  'ocupada', 'limpieza', e.fecha_hora_checkout_real
FROM estancia e
WHERE e.fecha_hora_checkout_real IS NOT NULL;

-- 5.3 queja: 50, distribuidas en reservaciones completadas y canceladas.
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO queja (id_huesped, id_reservacion, id_empleado, receptor, queja, fecha_queja, resolucion_queja, fecha_resolucion, departamento)
SELECT
  r.id_huesped,
  r.id_reservacion,
  ((r.id_reservacion * 31) % 50) + 1,
  CONCAT('Recepcion turno ', ELT(((n - 1) % 3) + 1, 'matutino','vespertino','nocturno')),
  ELT(((n - 1) % 10) + 1,
      'La habitacion no estaba limpia al llegar',
      'El aire acondicionado fallaba',
      'El servicio al cuarto tardo mas de 90 minutos',
      'El wifi se desconectaba con frecuencia',
      'Ruido excesivo en la habitacion contigua',
      'El desayuno buffet no tenia opciones suficientes',
      'Cobro inesperado en la cuenta',
      'Trato descortes en recepcion',
      'El spa cancelo cita sin aviso',
      'La alberca estaba cerrada por mantenimiento'),
  DATE_ADD(r.fecha_inicio, INTERVAL LEAST(2, DATEDIFF(r.fecha_salida, r.fecha_inicio) - 1) DAY),
  CASE WHEN n % 5 = 0 THEN NULL
       ELSE 'Atendido por gerencia, se ofrecio compensacion'
  END,
  CASE WHEN n % 5 = 0 THEN NULL
       ELSE DATE_ADD(r.fecha_inicio, INTERVAL LEAST(3, DATEDIFF(r.fecha_salida, r.fecha_inicio)) DAY)
  END,
  ELT(((n - 1) % 7) + 1,
      'recepcion','housekeeping','restaurante','spa','mantenimiento','seguridad','finanzas')
FROM seq
JOIN reservacion r ON r.id_reservacion = n
WHERE r.estado IN ('completada','cancelada');

-- 5.4 satisfaccion: 50, una por reservacion completada (con calificacion).
WITH RECURSIVE seq AS (SELECT 1 AS n UNION ALL SELECT n+1 FROM seq WHERE n < 50)
INSERT INTO satisfaccion (id_huesped, id_reservacion, id_empleado, departamento, receptor, comentarios, fecha_satisfaccion, calificacion)
SELECT
  r.id_huesped,
  r.id_reservacion,
  ((r.id_reservacion * 37) % 50) + 1,
  ELT(((n - 1) % 7) + 1,
      'recepcion','housekeeping','restaurante','spa','gimnasio','entretenimiento','concierge'),
  CONCAT('Encuesta salida turno ', ELT(((n - 1) % 3) + 1, 'matutino','vespertino','nocturno')),
  ELT(((n - 1) % 8) + 1,
      'Excelente servicio, regresare pronto',
      'Muy buen trato del personal',
      'Habitacion comoda y limpia',
      'Comida sobresaliente',
      'Spa de primer nivel',
      'Algunos detalles por mejorar pero general bien',
      'Recomendable, sin duda volveria',
      'Experiencia mejor a lo esperado'),
  r.fecha_salida,
  -- distribucion: 60% 5-estrellas, 25% 4, 10% 3, 5% 2.
  CASE
    WHEN n % 20 = 0 THEN 2
    WHEN n % 10 = 0 THEN 3
    WHEN n %  4 = 0 THEN 4
    ELSE                5
  END
FROM seq
JOIN reservacion r ON r.id_reservacion = n
WHERE r.estado = 'completada';

-- ---------------------------------------------------------------------
-- 6. RECONCILIACION DE TOTALES Y CONTADORES (verdad emerge desde los datos)
-- ---------------------------------------------------------------------

-- 6.1 Subtotal/total por reservacion = suma de reservacion_habitacion + consumo_servicio.
UPDATE reservacion r
LEFT JOIN (SELECT id_reservacion, SUM(subtotal) AS s FROM reservacion_habitacion GROUP BY id_reservacion) rh
       ON rh.id_reservacion = r.id_reservacion
LEFT JOIN (SELECT id_reservacion, SUM(cantidad * precio_unitario) AS s FROM consumo_servicio GROUP BY id_reservacion) cs
       ON cs.id_reservacion = r.id_reservacion
SET r.subtotal = COALESCE(rh.s, 0) + COALESCE(cs.s, 0),
    r.total    = ROUND((COALESCE(rh.s, 0) + COALESCE(cs.s, 0)) * 1.16, 2);

-- 6.2 cuenta.subtotal/total = suma de detalle_cuenta.
UPDATE cuenta c
JOIN (
  SELECT id_cuenta,
         SUM(cantidad * precio_unitario - descuento) AS subt,
         SUM(cantidad * precio_unitario - descuento + impuesto) AS tot
  FROM detalle_cuenta GROUP BY id_cuenta
) d ON d.id_cuenta = c.id_cuenta
SET c.subtotal = d.subt,
    c.total    = d.tot;

-- 6.3 factura.subtotal/impuestos/total derivados de la cuenta.
UPDATE factura f
JOIN cuenta c ON c.id_cuenta = f.id_cuenta
SET f.subtotal  = c.subtotal,
    f.impuestos = ROUND(c.subtotal * 0.16, 2),
    f.total     = c.total;

-- 6.4 pago.monto = factura.total (cuando aplica).
UPDATE pago p
JOIN factura f ON f.id_factura = p.id_factura
SET p.monto = CASE WHEN p.estado = 'completado' THEN f.total
                   WHEN p.estado = 'reembolsado' THEN f.total
                   ELSE ROUND(f.total * 0.50, 2)
              END;

-- 6.5 huesped_facturador.numero_reservas = COUNT(reservaciones).
UPDATE huesped_facturador hf
LEFT JOIN (SELECT id_huesped_facturador, COUNT(*) AS c FROM reservacion GROUP BY id_huesped_facturador) r
       ON r.id_huesped_facturador = hf.id_huesped_facturador
SET hf.numero_reservas = COALESCE(r.c, 0);

-- 6.6 cliente_vip.contador_reservas = COUNT(reservaciones efectivas: no canceladas).
UPDATE cliente_vip cv
JOIN huesped_facturador hf ON hf.id_huesped_facturador = cv.id_huesped_facturador
LEFT JOIN (
  SELECT id_huesped_facturador, COUNT(*) AS c
  FROM reservacion
  WHERE estado <> 'cancelada'
  GROUP BY id_huesped_facturador
) r ON r.id_huesped_facturador = hf.id_huesped_facturador
SET cv.contador_reservas = COALESCE(r.c, 0);

-- 6.7 habitacion.estado refleja las 10 estancias activas (check_in actual).
UPDATE habitacion h
JOIN estancia e ON e.id_habitacion = h.id_habitacion AND e.fecha_hora_checkout_real IS NULL
SET h.estado = 'ocupada';

-- ---------------------------------------------------------------------
-- 7. VERIFICACION DE MINIMOS (consultas de sanity check)
-- ---------------------------------------------------------------------
-- Ejecutar manualmente despues de cargar:
--
-- SELECT table_name, table_rows FROM information_schema.tables
-- WHERE table_schema = 'hotel_alpheus'
-- ORDER BY table_name;
--
-- Toda tabla debe reportar >= 50 filas excepto las que dependen de
-- reservaciones con estados especificos (estancia=60, cuenta=60,
-- factura=50, pago=50, cancelacion=50, etc.)
-- =====================================================================
