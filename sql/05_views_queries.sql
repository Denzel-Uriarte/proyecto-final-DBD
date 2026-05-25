-- Para ejecutar todo el archivo: source sql/05_views_queries.sql
-- Para ejecutar una sola consulta: copiar el bloque correspondiente.

USE hotel_alpheus;

-- Parametros globales reutilizados (override antes del SELECT si se desea).
SET @hoy        := CURRENT_DATE;
SET @desde_mes  := DATE_SUB(@hoy, INTERVAL 1 MONTH);
SET @hasta_mes  := @hoy;
SET @desde_ano  := DATE_SUB(@hoy, INTERVAL 1 YEAR);
SET @hasta_ano  := @hoy;


-- 1) Habitaciones disponibles en un rango de fechas
--    Devuelve las habitaciones que no estan fuera de servicio ni en
--    mantenimiento y no tienen ninguna reservacion pendiente,
--    confirmada o con check_in cuyo rango se solape con [@desde, @hasta].
SET @desde := @hoy;
SET @hasta := DATE_ADD(@hoy, INTERVAL 1 DAY);

SELECT
  h.id_habitacion,
  h.numero_habitacion,
  h.piso,
  ch.nombre              AS categoria,
  h.precio               AS tarifa_noche,
  h.estado               AS estado_actual
FROM habitacion h
JOIN categoria_habitacion ch
  ON ch.id_categoria = h.id_categoria
WHERE h.estado IN ('disponible', 'limpieza')
  AND NOT EXISTS (
    SELECT 1
    FROM reservacion_habitacion rh
    JOIN reservacion r ON r.id_reservacion = rh.id_reservacion
    WHERE rh.id_habitacion = h.id_habitacion
      AND r.estado IN ('pendiente', 'confirmada', 'check_in')
      AND r.fecha_inicio < @hasta
      AND r.fecha_salida > @desde
  )
ORDER BY ch.nombre, h.numero_habitacion;


-- 2) Clientes hospedados (check-in vigente)
--    Estancias sin checkout real. Muestra fecha de ingreso/salida, nombre del huesped y tipo de habitacion.
SELECT
  e.id_estancia,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  DATE(e.fecha_hora_checkin)                     AS fecha_ingreso,
  DATE(r.fecha_salida)                           AS fecha_fin_reserva,
  hab.numero_habitacion                          AS habitacion,
  ch.nombre                                      AS tipo_habitacion
FROM estancia e
JOIN reservacion r           ON r.id_reservacion = e.id_reservacion
JOIN huesped h               ON h.id_huesped     = r.id_huesped
JOIN habitacion hab          ON hab.id_habitacion = e.id_habitacion
JOIN categoria_habitacion ch ON ch.id_categoria   = hab.id_categoria
WHERE e.fecha_hora_checkout_real IS NULL
ORDER BY e.fecha_hora_checkin DESC;


-- 3) Clientes con reserva en una fecha y sin check-in
--    Reservas que se solapan con @fecha pero todavia no tienen estancia.
SET @fecha := @hoy;

SELECT
  r.id_reservacion,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  hf.email                                       AS email_facturador,
  r.fecha_inicio,
  r.fecha_salida,
  r.estado,
  r.metodo,
  r.total
FROM reservacion r
JOIN huesped h             ON h.id_huesped = r.id_huesped
JOIN huesped_facturador hf ON hf.id_huesped_facturador = r.id_huesped_facturador
WHERE r.estado IN ('pendiente', 'confirmada')
  AND r.fecha_inicio <= @fecha
  AND r.fecha_salida >  @fecha
  AND NOT EXISTS (
    SELECT 1 FROM estancia e WHERE e.id_reservacion = r.id_reservacion
  )
ORDER BY r.fecha_inicio;


-- 4) Ocupacion de habitaciones por tipo en una fecha
--    Para cada categoria muestra total de habitaciones, ocupadas en @fecha y porcentaje de ocupacion.
SET @fecha := @hoy;

SELECT
  ch.nombre                                          AS categoria,
  COUNT(DISTINCT h.id_habitacion)                    AS total_habitaciones,
  COUNT(DISTINCT CASE
    WHEN EXISTS (
      SELECT 1 FROM estancia e
      WHERE e.id_habitacion = h.id_habitacion
        AND DATE(e.fecha_hora_checkin) <= @fecha
        AND (e.fecha_hora_checkout_real IS NULL
             OR DATE(e.fecha_hora_checkout_real) > @fecha)
    ) THEN h.id_habitacion END)                      AS ocupadas,
  ROUND(100 * COUNT(DISTINCT CASE
    WHEN EXISTS (
      SELECT 1 FROM estancia e
      WHERE e.id_habitacion = h.id_habitacion
        AND DATE(e.fecha_hora_checkin) <= @fecha
        AND (e.fecha_hora_checkout_real IS NULL
             OR DATE(e.fecha_hora_checkout_real) > @fecha)
    ) THEN h.id_habitacion END)
        / COUNT(DISTINCT h.id_habitacion), 2)        AS porcentaje_ocupacion
FROM habitacion h
JOIN categoria_habitacion ch ON ch.id_categoria = h.id_categoria
GROUP BY ch.id_categoria, ch.nombre
ORDER BY porcentaje_ocupacion DESC, ch.nombre;


-- 5) Proyeccion de reservas en los proximos 7 dias
--    Reservas confirmadas o pendientes cuyo check-in cae en (@hoy,@hoy+7].
SELECT
  r.id_reservacion,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  hf.telefono_celular,
  r.fecha_inicio,
  r.fecha_salida,
  DATEDIFF(r.fecha_salida, r.fecha_inicio)       AS noches,
  r.estado,
  r.total
FROM reservacion r
JOIN huesped h             ON h.id_huesped = r.id_huesped
JOIN huesped_facturador hf ON hf.id_huesped_facturador = r.id_huesped_facturador
WHERE r.estado IN ('pendiente', 'confirmada')
  AND r.fecha_inicio >  @hoy
  AND r.fecha_inicio <= DATE_ADD(@hoy, INTERVAL 7 DAY)
ORDER BY r.fecha_inicio, r.id_reservacion;


-- 6) Reservas canceladas en el ultimo mes
--    Rango por defecto: @hoy - 30 dias .. @hoy.
SELECT
  c.id_cancelacion,
  c.id_reservacion,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  c.fecha_cancelacion,
  r.fecha_inicio                                 AS check_in_original,
  c.motivo,
  c.penalizacion,
  r.total                                        AS total_reserva
FROM cancelacion c
JOIN reservacion r ON r.id_reservacion = c.id_reservacion
JOIN huesped h     ON h.id_huesped     = r.id_huesped
WHERE c.fecha_cancelacion >= @desde_mes
  AND c.fecha_cancelacion <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
ORDER BY c.fecha_cancelacion DESC;


-- 7) Clientes con mas de 5 reservas (potenciales VIP)
--    Conteo real desde reservacion (ignorando canceladas). Se devuelve
--    tambien el cache numero_reservas mantenido por trigger.
SELECT
  hf.id_huesped_facturador,
  CONCAT(h.nombres, ' ', h.apellidos)            AS cliente,
  hf.email,
  hf.numero_reservas                             AS cache_trigger,
  COUNT(*)                                       AS reservas_reales,
  COALESCE(v.nivel_vip, 'sin_vip')               AS nivel_vip
FROM huesped_facturador hf
JOIN huesped h           ON h.id_huesped = hf.id_huesped
JOIN reservacion r       ON r.id_huesped_facturador = hf.id_huesped_facturador
LEFT JOIN cliente_vip v  ON v.id_huesped_facturador = hf.id_huesped_facturador
WHERE r.estado <> 'cancelada'
GROUP BY hf.id_huesped_facturador, cliente, hf.email, hf.numero_reservas, v.nivel_vip
HAVING reservas_reales > 5
ORDER BY reservas_reales DESC;


-- 8) Servicios mas utilizados en un rango de fechas
--    Por defecto: ultimo mes.
SELECT
  s.id_servicio,
  s.nombre_servicio,
  ts.nombre                                      AS tipo_servicio,
  ts.categoria                                   AS origen,
  COUNT(*)                                       AS veces_consumido,
  SUM(cs.cantidad)                               AS unidades,
  SUM(cs.cantidad * cs.precio_unitario)          AS importe_total
FROM consumo_servicio cs
JOIN servicio s       ON s.id_servicio = cs.id_servicio
JOIN tipo_servicio ts ON ts.id_tipo_servicio = s.id_tipo_servicio
WHERE cs.fecha_hora >= @desde_mes
  AND cs.fecha_hora <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
GROUP BY s.id_servicio, s.nombre_servicio, ts.nombre, ts.categoria
ORDER BY veces_consumido DESC, importe_total DESC;


-- 9) Ingresos generados por rango de fechas (reporte rapido de finanzas)
--    Suma de pagos completados; tambien se reporta el monto pendiente y
--    reembolsado para una vision completa.
SELECT
  p.estado                                       AS estado_pago,
  COUNT(*)                                       AS num_pagos,
  SUM(p.monto)                                   AS monto
FROM pago p
WHERE p.fecha_pago >= @desde_mes
  AND p.fecha_pago <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
GROUP BY p.estado
ORDER BY FIELD(p.estado, 'completado', 'pendiente', 'reembolsado', 'fallido');


-- 10) Facturas emitidas en un rango y monto cobrado
--     Devuelve cada factura con el total cobrado real (suma de pagos
--     completados asociados).
SELECT
  f.id_factura,
  f.fecha_emision,
  CONCAT(h.nombres, ' ', h.apellidos)            AS facturado_a,
  hf.rfc,
  f.subtotal,
  f.impuestos,
  f.total                                        AS total_facturado,
  COALESCE((SELECT SUM(p.monto) FROM pago p
            WHERE p.id_factura = f.id_factura
              AND p.estado = 'completado'), 0)   AS total_cobrado,
  f.estado_factura
FROM factura f
JOIN huesped_facturador hf ON hf.id_huesped_facturador = f.id_huesped_facturador
JOIN huesped h             ON h.id_huesped = hf.id_huesped
WHERE f.fecha_emision >= @desde_mes
  AND f.fecha_emision <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
ORDER BY f.fecha_emision DESC, f.id_factura DESC;


-- 11) Top 10 mejores clientes del hotel (por monto total facturado)
SELECT
  hf.id_huesped_facturador,
  CONCAT(h.nombres, ' ', h.apellidos)            AS cliente,
  hf.email,
  hf.procedencia,
  COUNT(DISTINCT r.id_reservacion)               AS reservas,
  SUM(r.total)                                   AS ingreso_total,
  COALESCE(v.nivel_vip, 'sin_vip')               AS nivel_vip
FROM huesped_facturador hf
JOIN huesped h           ON h.id_huesped = hf.id_huesped
JOIN reservacion r       ON r.id_huesped_facturador = hf.id_huesped_facturador
LEFT JOIN cliente_vip v  ON v.id_huesped_facturador = hf.id_huesped_facturador
WHERE r.estado IN ('completada', 'check_in', 'confirmada')
GROUP BY hf.id_huesped_facturador, cliente, hf.email, hf.procedencia, v.nivel_vip
ORDER BY ingreso_total DESC, reservas DESC
LIMIT 10;


-- 12) Habitaciones no ocupadas en el ultimo mes
--     Habitaciones que no aparecen en ninguna estancia con check-in en
--     [@desde_mes, @hasta_mes].
SELECT
  h.id_habitacion,
  h.numero_habitacion,
  h.piso,
  ch.nombre                                      AS categoria,
  h.precio                                       AS tarifa_noche,
  h.estado                                       AS estado_actual
FROM habitacion h
JOIN categoria_habitacion ch ON ch.id_categoria = h.id_categoria
WHERE NOT EXISTS (
  SELECT 1 FROM estancia e
  WHERE e.id_habitacion = h.id_habitacion
    AND DATE(e.fecha_hora_checkin) >= @desde_mes
    AND DATE(e.fecha_hora_checkin) <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
)
ORDER BY ch.nombre, h.numero_habitacion;


-- 13) Duracion promedio de estancias por tipo de habitacion
--     Usa checkout real cuando existe, programado en caso contrario.
SELECT
  ch.nombre                                      AS categoria,
  COUNT(*)                                       AS estancias,
  ROUND(AVG(TIMESTAMPDIFF(HOUR,
        e.fecha_hora_checkin,
        COALESCE(e.fecha_hora_checkout_real,
                 e.fecha_hora_checkout_programado)) / 24.0), 2) AS noches_promedio,
  MIN(DATEDIFF(
        COALESCE(e.fecha_hora_checkout_real,
                 e.fecha_hora_checkout_programado),
        e.fecha_hora_checkin))                   AS noches_min,
  MAX(DATEDIFF(
        COALESCE(e.fecha_hora_checkout_real,
                 e.fecha_hora_checkout_programado),
        e.fecha_hora_checkin))                   AS noches_max
FROM estancia e
JOIN habitacion h            ON h.id_habitacion = e.id_habitacion
JOIN categoria_habitacion ch ON ch.id_categoria = h.id_categoria
GROUP BY ch.id_categoria, ch.nombre
ORDER BY noches_promedio DESC;


-- 14) Servicios no utilizados en el ultimo mes
SELECT
  s.id_servicio,
  s.nombre_servicio,
  ts.nombre                                      AS tipo_servicio,
  ts.categoria                                   AS origen,
  s.precio,
  s.disponible
FROM servicio s
JOIN tipo_servicio ts ON ts.id_tipo_servicio = s.id_tipo_servicio
WHERE NOT EXISTS (
  SELECT 1 FROM consumo_servicio cs
  WHERE cs.id_servicio = s.id_servicio
    AND cs.fecha_hora >= @desde_mes
    AND cs.fecha_hora <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
)
ORDER BY ts.categoria, ts.nombre, s.nombre_servicio;


-- 15) Reservas por tipo de habitacion en el ultimo ano
--     Para detectar demanda por categoria. Rango por defecto: 365 dias.
SELECT
  ch.nombre                                      AS categoria,
  COUNT(DISTINCT r.id_reservacion)               AS reservas,
  SUM(rh.noches * rh.cantidad_habitaciones)      AS noches_vendidas,
  SUM(rh.subtotal)                               AS ingreso_proyectado
FROM reservacion r
JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
JOIN habitacion h              ON h.id_habitacion = rh.id_habitacion
JOIN categoria_habitacion ch   ON ch.id_categoria = h.id_categoria
WHERE r.fecha_inicio >= @desde_ano
  AND r.fecha_inicio <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
  AND r.estado <> 'cancelada'
GROUP BY ch.id_categoria, ch.nombre
ORDER BY reservas DESC;


-- 16) Clientes que cancelaron mas de 2 reservas
--     Detalle por cancelacion: fecha de reserva, tipo de habitacion
--     y motivo registrado.
SELECT
  CONCAT(h.nombres, ' ', h.apellidos)            AS cliente,
  hf.email,
  cuenta_cancelaciones.total_cancelaciones,
  r.id_reservacion,
  r.fecha_inicio                                 AS fecha_reservada,
  ch.nombre                                      AS tipo_habitacion,
  c.fecha_cancelacion,
  c.motivo
FROM cancelacion c
JOIN reservacion r             ON r.id_reservacion = c.id_reservacion
JOIN huesped_facturador hf     ON hf.id_huesped_facturador = r.id_huesped_facturador
JOIN huesped h                 ON h.id_huesped = hf.id_huesped
JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
JOIN habitacion hab            ON hab.id_habitacion = rh.id_habitacion
JOIN categoria_habitacion ch   ON ch.id_categoria = hab.id_categoria
JOIN (
  SELECT r2.id_huesped_facturador,
         COUNT(*) AS total_cancelaciones
  FROM cancelacion c2
  JOIN reservacion r2 ON r2.id_reservacion = c2.id_reservacion
  GROUP BY r2.id_huesped_facturador
  HAVING COUNT(*) > 2
) cuenta_cancelaciones
  ON cuenta_cancelaciones.id_huesped_facturador = hf.id_huesped_facturador
ORDER BY cuenta_cancelaciones.total_cancelaciones DESC,
         cliente, c.fecha_cancelacion DESC;


-- 17) Numero de reservas por pais de origen
SELECT
  COALESCE(h.pais_origen, '(sin pais)')          AS pais_origen,
  COUNT(*)                                       AS reservas,
  ROUND(100 * COUNT(*) /
        (SELECT COUNT(*) FROM reservacion), 2)   AS porcentaje_global
FROM reservacion r
JOIN huesped h ON h.id_huesped = r.id_huesped
GROUP BY h.pais_origen
ORDER BY reservas DESC, pais_origen;


-- 18) Promedio de facturacion diaria en un rango
--     Primero suma por dia, luego saca promedio sobre los dias con
--     emision. Tambien reporta total y desviacion estandar muestral.
SELECT
  MIN(diaria.fecha_emision)                      AS desde,
  MAX(diaria.fecha_emision)                      AS hasta,
  COUNT(*)                                       AS dias_con_factura,
  ROUND(AVG(diaria.total_dia), 2)                AS promedio_diario,
  ROUND(SUM(diaria.total_dia), 2)                AS total_periodo,
  ROUND(STDDEV_SAMP(diaria.total_dia), 2)        AS desviacion_diaria
FROM (
  SELECT f.fecha_emision,
         SUM(f.total) AS total_dia
  FROM factura f
  WHERE f.fecha_emision >= @desde_mes
    AND f.fecha_emision <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
  GROUP BY f.fecha_emision
) AS diaria;


-- 19) Clientes sin email registrado
SELECT
  h.id_huesped,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  h.fecha_nacimiento,
  h.pais_origen,
  CASE
    WHEN hf.id_huesped_facturador IS NULL THEN 'acompanante'
    ELSE 'facturador'
  END                                            AS rol
FROM huesped h
LEFT JOIN huesped_facturador hf ON hf.id_huesped = h.id_huesped
WHERE h.email IS NULL OR h.email = ''
ORDER BY rol, h.apellidos, h.nombres;


-- 20) Clientes VIP hospedados actualmente
--     Cruza estancias sin checkout con cliente_vip.
SELECT
  v.id_vip,
  v.nivel_vip,
  v.contador_reservas,
  v.puntos_acumulados,
  CONCAT(h.nombres, ' ', h.apellidos)            AS cliente,
  hab.numero_habitacion,
  ch.nombre                                      AS tipo_habitacion,
  DATE(e.fecha_hora_checkin)                     AS check_in,
  DATE(r.fecha_salida)                           AS check_out_programado
FROM estancia e
JOIN reservacion r           ON r.id_reservacion = e.id_reservacion
JOIN cliente_vip v           ON v.id_huesped_facturador = r.id_huesped_facturador
JOIN huesped_facturador hf   ON hf.id_huesped_facturador = v.id_huesped_facturador
JOIN huesped h               ON h.id_huesped = hf.id_huesped
JOIN habitacion hab          ON hab.id_habitacion = e.id_habitacion
JOIN categoria_habitacion ch ON ch.id_categoria = hab.id_categoria
WHERE e.fecha_hora_checkout_real IS NULL
ORDER BY FIELD(v.nivel_vip, 'platino', 'oro', 'plata', 'bronce'),
         v.contador_reservas DESC;


-- 21) Auditoria de cambios de estado de una habitacion
--     Cruza bitacora_habitacion con reservacion, huesped y empleado.
SET @id_habitacion := 1;

SELECT
  b.id_bitacora,
  b.fecha_hora                                   AS cambio,
  b.estado_anterior,
  b.estado_nuevo,
  hab.numero_habitacion,
  b.id_reservacion,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  r.total                                        AS costo_reserva,
  CONCAT(emp.nombres, ' ', emp.apellidos)        AS empleado,
  emp.rol                                        AS rol_empleado
FROM bitacora_habitacion b
JOIN habitacion hab           ON hab.id_habitacion = b.id_habitacion
LEFT JOIN reservacion r       ON r.id_reservacion = b.id_reservacion
LEFT JOIN huesped h           ON h.id_huesped = r.id_huesped
LEFT JOIN empleado emp        ON emp.id_empleado = b.id_empleado
WHERE b.id_habitacion = @id_habitacion
ORDER BY b.fecha_hora DESC;


-- 22) Facturas sin pagar o pendientes de pago
--     Pendientes o vencidas en el rango.
SELECT
  f.id_factura,
  f.fecha_emision,
  CONCAT(h.nombres, ' ', h.apellidos)            AS facturado_a,
  hf.rfc,
  hf.email,
  f.total,
  COALESCE((SELECT SUM(p.monto) FROM pago p
            WHERE p.id_factura = f.id_factura
              AND p.estado = 'completado'), 0)   AS pagado,
  f.estado_factura,
  DATEDIFF(@hoy, f.fecha_emision)                AS dias_desde_emision
FROM factura f
JOIN huesped_facturador hf ON hf.id_huesped_facturador = f.id_huesped_facturador
JOIN huesped h             ON h.id_huesped = hf.id_huesped
WHERE f.estado_factura IN ('pendiente', 'vencida')
  AND f.fecha_emision >= @desde_mes
  AND f.fecha_emision <  DATE_ADD(@hasta_mes, INTERVAL 1 DAY)
ORDER BY f.estado_factura DESC, f.fecha_emision;


-- 23) Reservas expiradas que no se actualizaron
--     Pendientes o confirmadas cuya fecha de salida ya paso. El evento
--     evt_auto_expirar_reservas (2h) deberia cerrarlas; lo que aparezca
--     aqui es una desviacion operativa.
SELECT
  r.id_reservacion,
  r.estado,
  r.metodo,
  CONCAT(h.nombres, ' ', h.apellidos)            AS huesped,
  hf.email,
  r.fecha_inicio,
  r.fecha_salida,
  DATEDIFF(@hoy, r.fecha_salida)                 AS dias_vencido,
  r.total
FROM reservacion r
JOIN huesped h             ON h.id_huesped = r.id_huesped
JOIN huesped_facturador hf ON hf.id_huesped_facturador = r.id_huesped_facturador
WHERE r.estado IN ('pendiente', 'confirmada')
  AND r.fecha_salida < @hoy
ORDER BY dias_vencido DESC;


-- 24) Porcentaje de ocupacion mensual clasificado por tipo de habitacion
--     Calcula noches ocupadas (sumando duracion de cada estancia) sobre
--     noches teoricas (numero_de_habitaciones * dias_del_mes).
SELECT
  DATE_FORMAT(e.fecha_hora_checkin, '%Y-%m')     AS mes,
  ch.nombre                                      AS categoria,
  SUM(DATEDIFF(
        COALESCE(e.fecha_hora_checkout_real,
                 e.fecha_hora_checkout_programado),
        e.fecha_hora_checkin))                   AS noches_ocupadas,
  hc.habitaciones_categoria
    * DAY(LAST_DAY(MIN(e.fecha_hora_checkin)))   AS noches_disponibles,
  ROUND(100 * SUM(DATEDIFF(
        COALESCE(e.fecha_hora_checkout_real,
                 e.fecha_hora_checkout_programado),
        e.fecha_hora_checkin))
    / (hc.habitaciones_categoria
       * DAY(LAST_DAY(MIN(e.fecha_hora_checkin)))), 2) AS porcentaje
FROM estancia e
JOIN habitacion h            ON h.id_habitacion = e.id_habitacion
JOIN categoria_habitacion ch ON ch.id_categoria = h.id_categoria
JOIN (
  SELECT id_categoria, COUNT(*) AS habitaciones_categoria
  FROM habitacion GROUP BY id_categoria
) hc ON hc.id_categoria = ch.id_categoria
WHERE e.fecha_hora_checkin >= @desde_ano
  AND e.fecha_hora_checkin <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
GROUP BY mes, ch.id_categoria, ch.nombre, hc.habitaciones_categoria
ORDER BY mes, porcentaje DESC;


-- 25) Ingresos por tipo de habitacion en un rango
--     Suma el subtotal de reservacion_habitacion (valor real cobrado
--     por noche x noches) para reservas no canceladas.
SELECT
  ch.nombre                                      AS categoria,
  COUNT(DISTINCT r.id_reservacion)               AS reservas,
  SUM(rh.noches * rh.cantidad_habitaciones)      AS noches_vendidas,
  SUM(rh.subtotal)                               AS ingreso_habitacion,
  ROUND(SUM(rh.subtotal) /
        NULLIF(SUM(rh.noches * rh.cantidad_habitaciones), 0), 2) AS adr
FROM reservacion r
JOIN reservacion_habitacion rh ON rh.id_reservacion = r.id_reservacion
JOIN habitacion h              ON h.id_habitacion = rh.id_habitacion
JOIN categoria_habitacion ch   ON ch.id_categoria = h.id_categoria
WHERE r.fecha_inicio >= @desde_ano
  AND r.fecha_inicio <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
  AND r.estado <> 'cancelada'
GROUP BY ch.id_categoria, ch.nombre
ORDER BY ingreso_habitacion DESC;


-- 26) Empleados y bono acumulado en un rango
SELECT
  emp.id_empleado,
  CONCAT(emp.nombres, ' ', emp.apellidos)        AS empleado,
  emp.departamento,
  emp.rol,
  emp.salario,
  COUNT(b.id_bono)                               AS num_bonos,
  COALESCE(SUM(b.monto), 0)                      AS bono_acumulado
FROM empleado emp
LEFT JOIN bono_empleado b
  ON b.id_empleado = emp.id_empleado
 AND b.fecha_hora >= @desde_ano
 AND b.fecha_hora <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
WHERE emp.activo = TRUE
GROUP BY emp.id_empleado, empleado, emp.departamento, emp.rol, emp.salario
ORDER BY bono_acumulado DESC, empleado;


-- 27) Servicios mas utilizados por clientes VIP
--     Solo huespedes en cliente_vip.
SELECT
  s.id_servicio,
  s.nombre_servicio,
  ts.nombre                                      AS tipo_servicio,
  ts.categoria                                   AS origen,
  COUNT(*)                                       AS consumos,
  SUM(cs.cantidad)                               AS unidades,
  SUM(cs.cantidad * cs.precio_unitario)          AS importe_total
FROM consumo_servicio cs
JOIN servicio s              ON s.id_servicio = cs.id_servicio
JOIN tipo_servicio ts        ON ts.id_tipo_servicio = s.id_tipo_servicio
JOIN reservacion r           ON r.id_reservacion = cs.id_reservacion
JOIN cliente_vip v           ON v.id_huesped_facturador = r.id_huesped_facturador
GROUP BY s.id_servicio, s.nombre_servicio, ts.nombre, ts.categoria
ORDER BY consumos DESC, importe_total DESC
LIMIT 20;


-- 28) Quejas registradas por departamento en un rango
--     Muestra total, tiempo medio de resolucion y porcentaje resueltas.
SELECT
  q.departamento,
  COUNT(*)                                       AS quejas,
  SUM(CASE WHEN q.fecha_resolucion IS NOT NULL THEN 1 ELSE 0 END) AS resueltas,
  ROUND(100 * SUM(CASE WHEN q.fecha_resolucion IS NOT NULL THEN 1 ELSE 0 END)
        / COUNT(*), 2)                           AS pct_resueltas,
  ROUND(AVG(CASE WHEN q.fecha_resolucion IS NOT NULL
                 THEN DATEDIFF(q.fecha_resolucion, q.fecha_queja)
            END), 2)                             AS dias_resolucion_promedio
FROM queja q
WHERE q.fecha_queja >= @desde_ano
  AND q.fecha_queja <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
GROUP BY q.departamento
ORDER BY quejas DESC;


-- 29) Departamento con mejor rating de satisfaccion en un rango
--     Devuelve el ranking; el primero es el de mejor rating.
SELECT
  s.departamento,
  COUNT(*)                                       AS encuestas,
  ROUND(AVG(s.calificacion), 2)                  AS rating_promedio,
  SUM(CASE WHEN s.calificacion >= 4 THEN 1 ELSE 0 END) AS satisfechos,
  ROUND(100 * SUM(CASE WHEN s.calificacion >= 4 THEN 1 ELSE 0 END)
        / COUNT(*), 2)                           AS pct_satisfechos
FROM satisfaccion s
WHERE s.fecha_satisfaccion >= @desde_ano
  AND s.fecha_satisfaccion <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
GROUP BY s.departamento
ORDER BY rating_promedio DESC, encuestas DESC;


-- 30) Habitaciones con mayor duracion de estancia clasificadas por tipo
--     Devuelve la habitacion con estancia mas larga por categoria en el
--     rango (ROW_NUMBER por categoria).
WITH rankeo AS (
  SELECT
    ch.nombre                                    AS categoria,
    h.numero_habitacion,
    e.id_estancia,
    DATEDIFF(
      COALESCE(e.fecha_hora_checkout_real,
               e.fecha_hora_checkout_programado),
      e.fecha_hora_checkin)                      AS noches,
    DATE(e.fecha_hora_checkin)                   AS check_in,
    DATE(COALESCE(e.fecha_hora_checkout_real,
                  e.fecha_hora_checkout_programado)) AS check_out,
    ROW_NUMBER() OVER (
      PARTITION BY ch.id_categoria
      ORDER BY DATEDIFF(
        COALESCE(e.fecha_hora_checkout_real,
                 e.fecha_hora_checkout_programado),
        e.fecha_hora_checkin) DESC,
      e.id_estancia
    )                                            AS rk
  FROM estancia e
  JOIN habitacion h            ON h.id_habitacion = e.id_habitacion
  JOIN categoria_habitacion ch ON ch.id_categoria = h.id_categoria
  WHERE e.fecha_hora_checkin >= @desde_ano
    AND e.fecha_hora_checkin <  DATE_ADD(@hasta_ano, INTERVAL 1 DAY)
)
SELECT categoria, numero_habitacion, check_in, check_out, noches
FROM rankeo
WHERE rk = 1
ORDER BY noches DESC;
