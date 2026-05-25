USE hotel_alpheus;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 3d) sp_verificar_disponibilidad
--     Verifica que la habitacion no este en mantenimiento/fuera de servicio y que no exista una reservacion no-cancelada que se solape con el rango.
--     OUT p_disponible: 1 = disponible, 0 = no.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_verificar_disponibilidad$$
CREATE PROCEDURE sp_verificar_disponibilidad(
  IN  p_id_habitacion INT UNSIGNED,
  IN  p_fecha_inicio  DATE,
  IN  p_fecha_salida  DATE,
  OUT p_disponible    TINYINT
)
BEGIN
  DECLARE v_estado     VARCHAR(20);
  DECLARE v_conflictos INT;

  IF p_fecha_salida <= p_fecha_inicio THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'fecha_salida debe ser estrictamente mayor a fecha_inicio';
  END IF;

  SELECT estado INTO v_estado
    FROM habitacion
   WHERE id_habitacion = p_id_habitacion;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Habitacion no existe';
  END IF;

  IF v_estado IN ('mantenimiento','fuera_de_servicio') THEN
    SET p_disponible = 0;
  ELSE
    SELECT COUNT(*) INTO v_conflictos
      FROM reservacion r
      JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
     WHERE rh.id_habitacion = p_id_habitacion
       AND r.estado NOT IN ('cancelada','expirada')
       AND r.fecha_inicio < p_fecha_salida
       AND r.fecha_salida > p_fecha_inicio;

    SET p_disponible = IF(v_conflictos = 0, 1, 0);
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 3a) sp_registrar_reserva
--     Crea reservacion + reservacion_habitacion en una sola transaccion. Valida disponibilidad antes de insertar (llama a sp_verificar_disponibilidad). Calcula subtotal con tarifa actual de la habitacion y aplica IVA 16% al total.
--     OUT p_id_reservacion: id generado.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_reserva$$
CREATE PROCEDURE sp_registrar_reserva(
  IN  p_id_huesped         INT UNSIGNED,
  IN  p_id_facturador      INT UNSIGNED,
  IN  p_id_usuario         INT UNSIGNED,
  IN  p_fecha_inicio       DATE,
  IN  p_fecha_salida       DATE,
  IN  p_metodo             VARCHAR(20),
  IN  p_id_habitacion      INT UNSIGNED,
  OUT p_id_reservacion     INT UNSIGNED
)
BEGIN
  DECLARE v_disponible TINYINT DEFAULT 0;
  DECLARE v_tarifa     DECIMAL(12,2);
  DECLARE v_noches     INT;
  DECLARE v_subtotal   DECIMAL(12,2);

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  CALL sp_verificar_disponibilidad(p_id_habitacion, p_fecha_inicio, p_fecha_salida, v_disponible);
  IF v_disponible = 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Habitacion no disponible en el rango solicitado';
  END IF;

  SELECT precio INTO v_tarifa
    FROM habitacion WHERE id_habitacion = p_id_habitacion;

  SET v_noches   = DATEDIFF(p_fecha_salida, p_fecha_inicio);
  SET v_subtotal = v_tarifa * v_noches;

  INSERT INTO reservacion
    (id_huesped, id_huesped_facturador, id_usuario, fecha_inicio, fecha_salida,
     estado, metodo, subtotal, total)
  VALUES
    (p_id_huesped, p_id_facturador, p_id_usuario, p_fecha_inicio, p_fecha_salida,
     'confirmada', p_metodo, v_subtotal, ROUND(v_subtotal * 1.16, 2));

  SET p_id_reservacion = LAST_INSERT_ID();

  INSERT INTO reservacion_habitacion
    (id_reservacion, id_habitacion, tarifa_por_noche, noches, cantidad_habitaciones, subtotal)
  VALUES
    (p_id_reservacion, p_id_habitacion, v_tarifa, v_noches, 1, v_subtotal);

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 3b) sp_cambiar_estado_habitacion
--     Cambia el estado de la habitacion y deja contexto para que el trigger trg_habitacion_after_update registre quien hizo el cambio en bitacora_habitacion. Las variables de sesion @bitacora_* se limpian al final.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cambiar_estado_habitacion$$
CREATE PROCEDURE sp_cambiar_estado_habitacion(
  IN p_id_habitacion  INT UNSIGNED,
  IN p_nuevo_estado   VARCHAR(20),
  IN p_id_empleado    INT UNSIGNED,
  IN p_id_reservacion INT UNSIGNED   -- NULL si no hay reservacion asociada
)
BEGIN
  IF p_nuevo_estado NOT IN ('disponible','ocupada','mantenimiento','limpieza','fuera_de_servicio') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Estado de habitacion no valido';
  END IF;

  SET @bitacora_id_empleado    = p_id_empleado;
  SET @bitacora_id_reservacion = p_id_reservacion;

  UPDATE habitacion
     SET estado = p_nuevo_estado
   WHERE id_habitacion = p_id_habitacion;

  SET @bitacora_id_empleado    = NULL;
  SET @bitacora_id_reservacion = NULL;
END$$

-- ---------------------------------------------------------------------
-- 3c) sp_checkout_rapido
--     Cierra la estancia (set checkout_real), cierra la cuenta, genera factura con totales reconciliados y marca la reservacion como 'completada'. El trigger trg_estancia_after_update se encarga de pasar la habitacion a 'limpieza'.
--     OUT p_id_factura: id de la factura generada.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_checkout_rapido$$
CREATE PROCEDURE sp_checkout_rapido(
  IN  p_id_reservacion INT UNSIGNED,
  IN  p_id_empleado    INT UNSIGNED,
  OUT p_id_factura     INT UNSIGNED
)
BEGIN
  DECLARE v_id_cuenta     INT UNSIGNED;
  DECLARE v_subtotal      DECIMAL(12,2);
  DECLARE v_total         DECIMAL(12,2);
  DECLARE v_id_facturador INT UNSIGNED;

  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  UPDATE estancia
     SET fecha_hora_checkout_real = NOW()
   WHERE id_reservacion = p_id_reservacion
     AND fecha_hora_checkout_real IS NULL;

  UPDATE cuenta
     SET fecha_cierre = CURRENT_DATE
   WHERE id_reservacion = p_id_reservacion
     AND fecha_cierre IS NULL;

  SELECT c.id_cuenta, c.subtotal, c.total, r.id_huesped_facturador
    INTO v_id_cuenta, v_subtotal, v_total, v_id_facturador
    FROM cuenta c
    JOIN reservacion r ON r.id_reservacion = c.id_reservacion
   WHERE c.id_reservacion = p_id_reservacion;

  IF v_id_cuenta IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No existe cuenta abierta para la reservacion indicada';
  END IF;

  INSERT INTO factura
    (id_cuenta, id_huesped_facturador, id_empleado,
     fecha_emision, subtotal, impuestos, total, estado_factura)
  VALUES
    (v_id_cuenta, v_id_facturador, p_id_empleado,
     CURRENT_DATE, v_subtotal, ROUND(v_subtotal * 0.16, 2), v_total, 'pagada');

  SET p_id_factura = LAST_INSERT_ID();

  -- Pago en efectivo automatico (factura rapida = pago al check-out)
  INSERT INTO pago
    (id_factura, fecha_pago, monto, metodo_pago, referencia, estado)
  VALUES
    (p_id_factura, CURRENT_DATE, v_total, 'efectivo',
     CONCAT('FAST-', LPAD(p_id_factura, 6, '0')), 'completado');

  UPDATE reservacion
     SET estado = 'completada'
   WHERE id_reservacion = p_id_reservacion;

  COMMIT;
END$$

-- ---------------------------------------------------------------------
-- 3e) sp_registrar_servicio
--     Registra un consumo de servicio para una reservacion activa. Si la cuenta esta abierta, agrega tambien una linea a detalle_cuenta.
--     OUT p_id_consumo: id del consumo creado.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_registrar_servicio$$
CREATE PROCEDURE sp_registrar_servicio(
  IN  p_id_reservacion INT UNSIGNED,
  IN  p_id_servicio    INT UNSIGNED,
  IN  p_id_empleado    INT UNSIGNED,
  IN  p_cantidad       INT,
  OUT p_id_consumo     INT UNSIGNED
)
BEGIN
  DECLARE v_precio       DECIMAL(12,2);
  DECLARE v_disponible   BOOLEAN;
  DECLARE v_id_huesped   INT UNSIGNED;
  DECLARE v_id_cuenta    INT UNSIGNED;
  DECLARE v_estado_res   VARCHAR(20);
  DECLARE v_nombre_serv  VARCHAR(100);

  IF p_cantidad <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La cantidad debe ser estrictamente positiva';
  END IF;

  SELECT precio, disponible, nombre_servicio
    INTO v_precio, v_disponible, v_nombre_serv
    FROM servicio WHERE id_servicio = p_id_servicio;

  IF v_precio IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Servicio no existe';
  END IF;
  IF v_disponible = FALSE THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Servicio no disponible';
  END IF;

  SELECT id_huesped, estado INTO v_id_huesped, v_estado_res
    FROM reservacion WHERE id_reservacion = p_id_reservacion;

  IF v_id_huesped IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservacion no existe';
  END IF;
  IF v_estado_res NOT IN ('check_in','confirmada','completada') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'No se puede registrar consumo en reservacion cancelada/expirada/pendiente';
  END IF;

  INSERT INTO consumo_servicio
    (id_reservacion, id_huesped, id_servicio, id_empleado,
     cantidad, precio_unitario, fecha_hora)
  VALUES
    (p_id_reservacion, v_id_huesped, p_id_servicio, p_id_empleado,
     p_cantidad, v_precio, NOW());

  SET p_id_consumo = LAST_INSERT_ID();

  SELECT id_cuenta INTO v_id_cuenta
    FROM cuenta WHERE id_reservacion = p_id_reservacion;

  IF v_id_cuenta IS NOT NULL THEN
    INSERT INTO detalle_cuenta
      (id_cuenta, tipo, descripcion, cantidad, precio_unitario,
       descuento, impuesto, importe)
    VALUES
      (v_id_cuenta, 'servicio', CONCAT('Servicio: ', v_nombre_serv),
       p_cantidad, v_precio, 0.00,
       ROUND(p_cantidad * v_precio * 0.16, 2),
       ROUND(p_cantidad * v_precio * 1.16, 2));
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 3f) sp_cancelar_reserva
--     Inserta un registro en cancelacion. Los triggers trg_cancelacion_* calculan la penalizacion (2j), marcan reservacion como 'cancelada' y liberan la habitacion si aplica.
--     OUT p_penalizacion: el monto calculado.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_cancelar_reserva$$
CREATE PROCEDURE sp_cancelar_reserva(
  IN  p_id_reservacion INT UNSIGNED,
  IN  p_id_usuario     INT UNSIGNED,
  IN  p_motivo         VARCHAR(255),
  OUT p_penalizacion   DECIMAL(12,2)
)
BEGIN
  DECLARE v_estado VARCHAR(20);

  SELECT estado INTO v_estado FROM reservacion WHERE id_reservacion = p_id_reservacion;

  IF v_estado IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Reservacion no existe';
  END IF;
  IF v_estado IN ('cancelada','completada','expirada') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La reservacion ya no puede ser cancelada (estado final)';
  END IF;

  INSERT INTO cancelacion
    (id_reservacion, id_usuario, motivo, penalizacion, fecha_cancelacion)
  VALUES
    (p_id_reservacion, p_id_usuario, p_motivo, 0.00, NOW());

  SELECT penalizacion INTO p_penalizacion
    FROM cancelacion WHERE id_reservacion = p_id_reservacion;
END$$

-- ---------------------------------------------------------------------
-- 3g) sp_actualizar_cliente_vip
--     Recalcula nivel_vip, puntos_acumulados y contador_reservas a partir del historial real (COUNT/SUM sobre reservacion). Usado cuando hay dudas sobre los contadores mantenidos por trigger o despues de operaciones masivas.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_actualizar_cliente_vip$$
CREATE PROCEDURE sp_actualizar_cliente_vip(
  IN p_id_facturador INT UNSIGNED
)
BEGIN
  DECLARE v_count_no_canceladas INT;
  DECLARE v_total_gasto         DECIMAL(12,2);
  DECLARE v_existe              INT;

  SELECT COUNT(*), COALESCE(SUM(total), 0)
    INTO v_count_no_canceladas, v_total_gasto
    FROM reservacion
   WHERE id_huesped_facturador = p_id_facturador
     AND estado NOT IN ('cancelada','expirada');

  SELECT COUNT(*) INTO v_existe
    FROM cliente_vip WHERE id_huesped_facturador = p_id_facturador;

  IF v_existe = 0 THEN
    INSERT INTO cliente_vip
      (id_huesped_facturador, nivel_vip, puntos_acumulados,
       contador_reservas, fecha_registro)
    VALUES
      (p_id_facturador,
       CASE
         WHEN v_count_no_canceladas >= 15 THEN 'platino'
         WHEN v_count_no_canceladas >= 10 THEN 'oro'
         WHEN v_count_no_canceladas >=  5 THEN 'plata'
         ELSE                                  'bronce'
       END,
       FLOOR(v_total_gasto / 100),
       v_count_no_canceladas,
       CURRENT_DATE);
  ELSE
    UPDATE cliente_vip
       SET nivel_vip = CASE
             WHEN v_count_no_canceladas >= 15 THEN 'platino'
             WHEN v_count_no_canceladas >= 10 THEN 'oro'
             WHEN v_count_no_canceladas >=  5 THEN 'plata'
             ELSE                                  'bronce'
           END,
           puntos_acumulados = FLOOR(v_total_gasto / 100),
           contador_reservas = v_count_no_canceladas
     WHERE id_huesped_facturador = p_id_facturador;
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 3h) sp_listar_hospedados
--     Lista los huespedes actualmente hospedados (check-in sin checkout).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_listar_hospedados$$
CREATE PROCEDURE sp_listar_hospedados()
BEGIN
  SELECT r.id_reservacion,
         CONCAT(h.nombres, ' ', h.apellidos)   AS huesped,
         hab.numero_habitacion,
         ch.nombre                              AS categoria,
         e.fecha_hora_checkin,
         e.fecha_hora_checkout_programado,
         DATEDIFF(e.fecha_hora_checkout_programado, e.fecha_hora_checkin) AS noches,
         cv.nivel_vip
    FROM reservacion r
    JOIN estancia e             ON e.id_reservacion           = r.id_reservacion
    JOIN huesped h              ON h.id_huesped               = r.id_huesped
    JOIN habitacion hab         ON hab.id_habitacion          = e.id_habitacion
    JOIN categoria_habitacion ch ON ch.id_categoria           = hab.id_categoria
    LEFT JOIN cliente_vip cv    ON cv.id_huesped_facturador   = r.id_huesped_facturador
   WHERE e.fecha_hora_checkout_real IS NULL
     AND r.estado = 'check_in'
   ORDER BY e.fecha_hora_checkin;
END$$

-- ---------------------------------------------------------------------
-- 3i) sp_reporte_ingresos_mes
--     Reporte de ingresos del mes/anio indicados, desglosado por estado de factura para dar visibilidad al equipo de finanzas.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_reporte_ingresos_mes$$
CREATE PROCEDURE sp_reporte_ingresos_mes(
  IN p_year  INT,
  IN p_month INT
)
BEGIN
  SELECT DATE_FORMAT(f.fecha_emision, '%Y-%m')                                       AS mes,
         COUNT(*)                                                                    AS facturas_emitidas,
         COALESCE(SUM(f.subtotal), 0)                                                AS subtotal_total,
         COALESCE(SUM(f.impuestos), 0)                                               AS impuestos_total,
         COALESCE(SUM(f.total), 0)                                                   AS ingreso_total,
         COALESCE(SUM(CASE WHEN f.estado_factura = 'pagada'    THEN f.total END), 0) AS ingreso_cobrado,
         COALESCE(SUM(CASE WHEN f.estado_factura = 'pendiente' THEN f.total END), 0) AS por_cobrar,
         COALESCE(SUM(CASE WHEN f.estado_factura = 'vencida'   THEN f.total END), 0) AS vencido,
         COALESCE(SUM(CASE WHEN f.estado_factura = 'cancelada' THEN f.total END), 0) AS facturado_cancelado
    FROM factura f
   WHERE YEAR(f.fecha_emision)  = p_year
     AND MONTH(f.fecha_emision) = p_month
   GROUP BY DATE_FORMAT(f.fecha_emision, '%Y-%m');
END$$

-- ---------------------------------------------------------------------
-- 3j) sp_upgrade_vip
--     Upgrade automatico de habitacion para clientes oro/platino.
--     Busca la siguiente categoria de mayor precio_base que tenga al menos una habitacion disponible en el rango de la reservacion. Actualiza reservacion_habitacion in-place. OUT NULL si no hay upgrade.
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_upgrade_vip$$
CREATE PROCEDURE sp_upgrade_vip(
  IN  p_id_reservacion       INT UNSIGNED,
  OUT p_id_habitacion_nueva  INT UNSIGNED
)
BEGIN
  DECLARE v_nivel_vip      VARCHAR(20);
  DECLARE v_fecha_inicio   DATE;
  DECLARE v_fecha_salida   DATE;
  DECLARE v_id_hab_actual  INT UNSIGNED;
  DECLARE v_precio_actual  DECIMAL(12,2);

  SET p_id_habitacion_nueva = NULL;

  SELECT cv.nivel_vip, r.fecha_inicio, r.fecha_salida,
         rh.id_habitacion, ch.precio_base
    INTO v_nivel_vip, v_fecha_inicio, v_fecha_salida,
         v_id_hab_actual, v_precio_actual
    FROM reservacion r
    JOIN cliente_vip cv          ON cv.id_huesped_facturador = r.id_huesped_facturador
    JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
    JOIN habitacion hab          ON hab.id_habitacion = rh.id_habitacion
    JOIN categoria_habitacion ch ON ch.id_categoria = hab.id_categoria
   WHERE r.id_reservacion = p_id_reservacion
   LIMIT 1;

  IF v_nivel_vip IS NULL THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'Reservacion sin cliente VIP asociado';
  END IF;

  IF v_nivel_vip NOT IN ('oro','platino') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El cliente no califica para upgrade (requiere nivel oro o platino)';
  END IF;

  SELECT h.id_habitacion INTO p_id_habitacion_nueva
    FROM habitacion h
    JOIN categoria_habitacion ch ON ch.id_categoria = h.id_categoria
   WHERE ch.precio_base > v_precio_actual
     AND h.estado IN ('disponible','limpieza')
     AND NOT EXISTS (
       SELECT 1
         FROM reservacion r2
         JOIN reservacion_habitacion rh2 ON rh2.id_reservacion = r2.id_reservacion
        WHERE rh2.id_habitacion = h.id_habitacion
          AND r2.id_reservacion <> p_id_reservacion
          AND r2.estado NOT IN ('cancelada','expirada')
          AND r2.fecha_inicio < v_fecha_salida
          AND r2.fecha_salida > v_fecha_inicio
     )
   ORDER BY ch.precio_base ASC, h.id_habitacion ASC
   LIMIT 1;

  IF p_id_habitacion_nueva IS NOT NULL THEN
    UPDATE reservacion_habitacion
       SET id_habitacion = p_id_habitacion_nueva
     WHERE id_reservacion = p_id_reservacion;
  END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- Verificacion: listar procedures.
-- Ejecutar manualmente:
--   SHOW PROCEDURE STATUS WHERE Db = 'hotel_alpheus';
-- =====================================================================
