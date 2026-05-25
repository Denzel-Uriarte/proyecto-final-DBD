-- =====================================================================
-- Hotel Alpheus - Triggers (lineamientos 2a-2j)
-- CETYS Universidad - Diseno de Bases de Datos 2026-1, Proyecto Final
-- =====================================================================
-- 10 triggers + 1 event programado, mapeados 1:1 al lineamiento del PDF.
--
-- ORDEN DE EJECUCION OBLIGATORIO:
--   1) sql/01_schema.sql
--   2) sql/02_seed.sql
--   3) sql/03_triggers.sql   <- este archivo
--
-- Si se ejecutan los triggers ANTES del seed, los AFTER INSERT se disparan
-- durante la carga y chocan con los inserts explicitos del seed
-- (e.g., trg_hf_after_insert crearia cliente_vip duplicado).
-- Para re-cargar todo en limpio, ejecutar DROP DATABASE hotel_alpheus
-- (lo hace sql/01_schema.sql automaticamente).
--
-- Cobertura por lineamiento:
--   2a Check-in -> habitacion 'ocupada'           -> trg_estancia_after_insert
--   2b Termino estancia -> liberar habitacion     -> trg_estancia_after_update
--   2c Bitacora cambio estado habitacion          -> trg_habitacion_after_update
--   2d Alta auto a cliente_vip                    -> trg_hf_after_insert
--   2e Contador VIP al reservar                   -> trg_reservacion_after_insert
--   2f Validar fechas reserva                     -> trg_reservacion_before_iu
--   2g Control inventario habitaciones            -> trg_estancia_before_insert
--   2h Auto-cancelar reservas sin check-in        -> evt_auto_expirar_reservas
--   2i Evitar servicios con precio <= 0           -> trg_servicio_before_iu,
--                                                    trg_consumo_before_iu
--   2j Penalizacion 55% si cancelacion tardia     -> trg_cancelacion_before_insert
--                                                  + trg_cancelacion_after_insert
-- =====================================================================

USE hotel_alpheus;

DELIMITER $$

-- ---------------------------------------------------------------------
-- 2a) trg_estancia_after_insert
--     Al hacer check-in (insertar fila en estancia), marcar la
--     habitacion como 'ocupada'. Esto a su vez dispara
--     trg_habitacion_after_update -> bitacora_habitacion (2c).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_estancia_after_insert$$
CREATE TRIGGER trg_estancia_after_insert
AFTER INSERT ON estancia
FOR EACH ROW
BEGIN
  UPDATE habitacion
     SET estado = 'ocupada'
   WHERE id_habitacion = NEW.id_habitacion
     AND estado <> 'ocupada';
END$$

-- ---------------------------------------------------------------------
-- 2b) trg_estancia_after_update
--     Al cerrar la estancia (fecha_hora_checkout_real cambia de NULL a
--     valor), pasar la habitacion a 'limpieza'. Despues operaciones
--     puede pasarla a 'disponible' manualmente o via SP.
--     Usar 'limpieza' refleja el flujo real (no se puede revender al
--     siguiente huesped sin housekeeping previo).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_estancia_after_update$$
CREATE TRIGGER trg_estancia_after_update
AFTER UPDATE ON estancia
FOR EACH ROW
BEGIN
  IF OLD.fecha_hora_checkout_real IS NULL
     AND NEW.fecha_hora_checkout_real IS NOT NULL THEN
    UPDATE habitacion
       SET estado = 'limpieza'
     WHERE id_habitacion = NEW.id_habitacion
       AND estado = 'ocupada';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2c) trg_habitacion_after_update
--     Cada vez que cambia el estado de una habitacion, dejar registro
--     en bitacora_habitacion. id_empleado/id_reservacion quedan NULL
--     si el cambio fue automatico (no podemos saberlo desde el trigger
--     sin contexto adicional; los SPs si los pasan via variables de
--     sesion - se atienden en 04_procedures.sql).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_habitacion_after_update$$
CREATE TRIGGER trg_habitacion_after_update
AFTER UPDATE ON habitacion
FOR EACH ROW
BEGIN
  IF OLD.estado <> NEW.estado THEN
    INSERT INTO bitacora_habitacion
      (id_habitacion, id_empleado, id_reservacion,
       estado_anterior, estado_nuevo, fecha_hora)
    VALUES
      (NEW.id_habitacion,
       @bitacora_id_empleado,    -- set por SPs; NULL si no hay contexto
       @bitacora_id_reservacion, -- idem
       OLD.estado, NEW.estado, NOW());
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2d) trg_hf_after_insert
--     Cada vez que se registra un huesped facturador, agregarlo
--     automaticamente a cliente_vip como 'bronce'. INSERT IGNORE evita
--     romper re-corridas (uq sobre id_huesped_facturador).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_hf_after_insert$$
CREATE TRIGGER trg_hf_after_insert
AFTER INSERT ON huesped_facturador
FOR EACH ROW
BEGIN
  INSERT IGNORE INTO cliente_vip
    (id_huesped_facturador, nivel_vip, puntos_acumulados,
     contador_reservas, fecha_registro)
  VALUES
    (NEW.id_huesped_facturador, 'bronce', 0, 0, CURRENT_DATE);
END$$

-- ---------------------------------------------------------------------
-- 2e) trg_reservacion_after_insert
--     Incrementa el contador personal del cliente VIP y mantiene
--     numero_reservas en huesped_facturador (cache controlado por
--     trigger; fuente de verdad sigue siendo COUNT(*) sobre reservacion).
--     Tambien promueve el nivel_vip cuando se rebasan umbrales.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_reservacion_after_insert$$
CREATE TRIGGER trg_reservacion_after_insert
AFTER INSERT ON reservacion
FOR EACH ROW
BEGIN
  UPDATE huesped_facturador
     SET numero_reservas = numero_reservas + 1
   WHERE id_huesped_facturador = NEW.id_huesped_facturador;

  UPDATE cliente_vip
     SET contador_reservas  = contador_reservas + 1,
         puntos_acumulados  = puntos_acumulados
                              + GREATEST(FLOOR(NEW.total / 100), 0),
         nivel_vip = CASE
           WHEN contador_reservas + 1 >= 15 THEN 'platino'
           WHEN contador_reservas + 1 >= 10 THEN 'oro'
           WHEN contador_reservas + 1 >=  5 THEN 'plata'
           ELSE                                   nivel_vip
         END
   WHERE id_huesped_facturador = NEW.id_huesped_facturador;
END$$

-- ---------------------------------------------------------------------
-- 2f) trg_reservacion_before_iu (BEFORE INSERT + BEFORE UPDATE)
--     Valida fecha_salida > fecha_inicio. El CHECK constraint del
--     schema ya valida lo mismo; este trigger es defense-in-depth y
--     entrega un mensaje de error mas explicativo.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_reservacion_before_insert$$
CREATE TRIGGER trg_reservacion_before_insert
BEFORE INSERT ON reservacion
FOR EACH ROW
BEGIN
  IF NEW.fecha_salida <= NEW.fecha_inicio THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'fecha_salida debe ser estrictamente mayor a fecha_inicio';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_reservacion_before_update$$
CREATE TRIGGER trg_reservacion_before_update
BEFORE UPDATE ON reservacion
FOR EACH ROW
BEGIN
  IF NEW.fecha_salida <= NEW.fecha_inicio THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'fecha_salida debe ser estrictamente mayor a fecha_inicio';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2g) trg_estancia_before_insert
--     Control de inventario: bloquear check-in si la habitacion
--     no esta 'disponible' o 'limpieza'. Esto evita doble asignacion.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_estancia_before_insert$$
CREATE TRIGGER trg_estancia_before_insert
BEFORE INSERT ON estancia
FOR EACH ROW
BEGIN
  DECLARE v_estado VARCHAR(20);

  SELECT estado INTO v_estado
    FROM habitacion
   WHERE id_habitacion = NEW.id_habitacion;

  IF v_estado NOT IN ('disponible', 'limpieza') THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La habitacion no esta disponible para check-in (estado actual no permite asignacion)';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2h) evt_auto_expirar_reservas (EVENT, no TRIGGER)
--     Una vez al dia revisa reservas en estado 'pendiente' o
--     'confirmada' cuya fecha_inicio ya paso sin estancia asociada,
--     y las marca como 'expirada'. Requiere event_scheduler activado.
-- ---------------------------------------------------------------------
DROP EVENT IF EXISTS evt_auto_expirar_reservas$$
CREATE EVENT evt_auto_expirar_reservas
ON SCHEDULE EVERY 1 DAY
STARTS CURRENT_DATE + INTERVAL 1 DAY + INTERVAL 3 HOUR
DO
BEGIN
  UPDATE reservacion r
    LEFT JOIN estancia e ON e.id_reservacion = r.id_reservacion
     SET r.estado = 'expirada'
   WHERE r.estado IN ('pendiente','confirmada')
     AND r.fecha_inicio < CURRENT_DATE
     AND e.id_estancia IS NULL;
END$$

-- ---------------------------------------------------------------------
-- 2i) trg_servicio_before_iu + trg_consumo_before_iu
--     Evitar precios <= 0 en servicios y consumos. Los CHECK del schema
--     ya validan; los triggers entregan un mensaje claro al operador.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_servicio_before_insert$$
CREATE TRIGGER trg_servicio_before_insert
BEFORE INSERT ON servicio
FOR EACH ROW
BEGIN
  IF NEW.precio <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El precio del servicio debe ser estrictamente positivo';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_servicio_before_update$$
CREATE TRIGGER trg_servicio_before_update
BEFORE UPDATE ON servicio
FOR EACH ROW
BEGIN
  IF NEW.precio <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El precio del servicio debe ser estrictamente positivo';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_consumo_before_insert$$
CREATE TRIGGER trg_consumo_before_insert
BEFORE INSERT ON consumo_servicio
FOR EACH ROW
BEGIN
  IF NEW.precio_unitario <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El precio unitario del consumo debe ser estrictamente positivo';
  END IF;
  IF NEW.cantidad <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'La cantidad del consumo debe ser estrictamente positiva';
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_consumo_before_update$$
CREATE TRIGGER trg_consumo_before_update
BEFORE UPDATE ON consumo_servicio
FOR EACH ROW
BEGIN
  IF NEW.precio_unitario <= 0 THEN
    SIGNAL SQLSTATE '45000'
      SET MESSAGE_TEXT = 'El precio unitario del consumo debe ser estrictamente positivo';
  END IF;
END$$

-- ---------------------------------------------------------------------
-- 2j) trg_cancelacion_before_insert + trg_cancelacion_after_insert
--     Penalizacion 55% del subtotal de la reservacion si la cancelacion
--     cae dentro de la "ventana de penalizacion" (< 7 dias antes del
--     check-in). Si cancela con anticipacion >= 7 dias, penalizacion 0.
--     Despues del INSERT marca la reservacion como 'cancelada' y libera
--     la habitacion si ya estaba ocupada (caso raro: no-show).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_cancelacion_before_insert$$
CREATE TRIGGER trg_cancelacion_before_insert
BEFORE INSERT ON cancelacion
FOR EACH ROW
BEGIN
  DECLARE v_fecha_inicio  DATE;
  DECLARE v_subtotal      DECIMAL(12,2);
  DECLARE v_anticipacion  INT;

  SELECT fecha_inicio INTO v_fecha_inicio
    FROM reservacion
   WHERE id_reservacion = NEW.id_reservacion;

  SELECT COALESCE(SUM(subtotal), 0) INTO v_subtotal
    FROM reservacion_habitacion
   WHERE id_reservacion = NEW.id_reservacion;

  SET v_anticipacion = DATEDIFF(v_fecha_inicio, DATE(NEW.fecha_cancelacion));

  IF v_anticipacion < 7 THEN
    SET NEW.penalizacion = ROUND(v_subtotal * 0.55, 2);
  ELSE
    SET NEW.penalizacion = 0.00;
  END IF;
END$$

DROP TRIGGER IF EXISTS trg_cancelacion_after_insert$$
CREATE TRIGGER trg_cancelacion_after_insert
AFTER INSERT ON cancelacion
FOR EACH ROW
BEGIN
  UPDATE reservacion
     SET estado = 'cancelada'
   WHERE id_reservacion = NEW.id_reservacion
     AND estado <> 'cancelada';

  -- Si por alguna razon la habitacion seguia ocupada (no-show real),
  -- la liberamos. Esto dispara trg_habitacion_after_update -> bitacora.
  UPDATE habitacion h
    JOIN reservacion_habitacion rh ON rh.id_habitacion = h.id_habitacion
   SET h.estado = 'disponible'
   WHERE rh.id_reservacion = NEW.id_reservacion
     AND h.estado = 'ocupada';
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- Activar el event scheduler para que evt_auto_expirar_reservas corra.
-- Requiere privilegio SUPER/SYSTEM_VARIABLES_ADMIN.
-- ---------------------------------------------------------------------
SET GLOBAL event_scheduler = ON;

-- ---------------------------------------------------------------------
-- Verificacion: listar triggers y events activos.
-- Ejecutar manualmente:
--   SHOW TRIGGERS FROM hotel_alpheus;
--   SHOW EVENTS  FROM hotel_alpheus;
-- =====================================================================
