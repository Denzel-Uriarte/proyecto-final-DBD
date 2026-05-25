USE hotel_alpheus;

--    limpieza
DROP USER IF EXISTS 'alpheus_admin'@'localhost';
DROP USER IF EXISTS 'alpheus_admin'@'%';
DROP USER IF EXISTS 'rec_carla'@'%';
DROP USER IF EXISTS 'rec_marco'@'%';
DROP USER IF EXISTS 'fin_lorena'@'%';
DROP USER IF EXISTS 'ger_alejandro'@'%';
DROP USER IF EXISTS 'rep_diana'@'%';
DROP USER IF EXISTS 'svc_app'@'%';

DROP ROLE IF EXISTS 'app_admin';
DROP ROLE IF EXISTS 'app_recepcion';
DROP ROLE IF EXISTS 'app_finanzas';
DROP ROLE IF EXISTS 'app_gerencia';
DROP ROLE IF EXISTS 'app_reportes';
DROP ROLE IF EXISTS 'app_aplicacion';


-- 1) Creacion de roles
CREATE ROLE 'app_admin';
CREATE ROLE 'app_recepcion';
CREATE ROLE 'app_finanzas';
CREATE ROLE 'app_gerencia';
CREATE ROLE 'app_reportes';
CREATE ROLE 'app_aplicacion';


-- 2.1 empleado_publico: omite salario y bono. Lo usan recepcion y reportes.
CREATE OR REPLACE VIEW empleado_publico AS
SELECT id_empleado, nombres, apellidos, rol, telefono, departamento, activo
FROM empleado;

-- 2.2 usuario_publico: omite el hash de contrasena. Lo usa gerencia.
CREATE OR REPLACE VIEW usuario_publico AS
SELECT id_usuario, email, rol
FROM usuario;

-- 2.3 reservacion_finanzas: agrega lo monetario para el rol de finanzas.
CREATE OR REPLACE VIEW reservacion_finanzas AS
SELECT r.id_reservacion,
       r.fecha_inicio,
       r.fecha_salida,
       r.estado,
       r.metodo,
       r.subtotal,
       r.total,
       hf.id_huesped_facturador,
       hf.rfc,
       hf.email AS email_facturador
FROM reservacion r
JOIN huesped_facturador hf ON hf.id_huesped_facturador = r.id_huesped_facturador;


-- 3.1 app_admin 
-- DBA de la base de datos: todos los privilegios dentro de hotel_alpheus
GRANT ALL PRIVILEGES ON hotel_alpheus.* TO 'app_admin' WITH GRANT OPTION;
GRANT SHOW DATABASES, PROCESS ON *.* TO 'app_admin';


-- 3.2 app_recepcion
-- Mostrador. Crea huespedes, reservas, estancias y consumos; NO ve compensaciones de empleados; NO toca facturas/pagos directamente
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.huesped             TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.huesped_facturador  TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.reservacion         TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.reservacion_habitacion TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.estancia            TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.cuenta              TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.detalle_cuenta      TO 'app_recepcion';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.consumo_servicio    TO 'app_recepcion';
GRANT SELECT, INSERT          ON hotel_alpheus.cancelacion        TO 'app_recepcion';
GRANT SELECT, INSERT          ON hotel_alpheus.queja              TO 'app_recepcion';
GRANT SELECT, INSERT          ON hotel_alpheus.satisfaccion       TO 'app_recepcion';

-- Solo lectura sobre catalogos y dimensiones
GRANT SELECT ON hotel_alpheus.habitacion                  TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.categoria_habitacion        TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.servicio                    TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.tipo_servicio               TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.evento_temporada            TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.paquete_promocional         TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.detalle_paquete_promocional TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.cliente_vip                 TO 'app_recepcion';
GRANT SELECT ON hotel_alpheus.bitacora_habitacion         TO 'app_recepcion';

-- Empleados: solo via vista publica
GRANT SELECT ON hotel_alpheus.empleado_publico            TO 'app_recepcion';

-- Procedures que usa el mostrador
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_registrar_reserva        TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_verificar_disponibilidad TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_cancelar_reserva         TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_registrar_servicio       TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_listar_hospedados        TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_cambiar_estado_habitacion TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_checkout_rapido          TO 'app_recepcion';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_upgrade_vip              TO 'app_recepcion';


-- 3.3 app_finanzas
-- Tesoreria/contabilidad. Ve TODO el universo monetario; mantiene
-- facturas, pagos y bonos. NO puede crear reservas ni cancelar (eso
-- es funcion del mostrador).
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.factura       TO 'app_finanzas';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.pago          TO 'app_finanzas';
GRANT SELECT, INSERT, UPDATE ON hotel_alpheus.bono_empleado TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.cuenta         TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.detalle_cuenta TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.reservacion    TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.reservacion_habitacion TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.cancelacion    TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.consumo_servicio TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.servicio       TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.tipo_servicio  TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.huesped        TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.huesped_facturador TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.cliente_vip    TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.habitacion     TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.categoria_habitacion TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.empleado       TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.estancia       TO 'app_finanzas';
GRANT SELECT                ON hotel_alpheus.reservacion_finanzas TO 'app_finanzas';

GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_checkout_rapido      TO 'app_finanzas';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_reporte_ingresos_mes TO 'app_finanzas';


-- 3.4 app_gerencia
-- Direccion. Lectura completa, escritura sobre dimensiones de RRHH y
-- decisiones de calidad. Puede ejecutar cualquier procedure operativo
-- para resolver casos especiales.
GRANT SELECT ON hotel_alpheus.*                       TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.empleado        TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.bono_empleado   TO 'app_gerencia';
GRANT UPDATE         ON hotel_alpheus.queja           TO 'app_gerencia';
GRANT UPDATE         ON hotel_alpheus.satisfaccion    TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.categoria_habitacion TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.habitacion      TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.servicio        TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.tipo_servicio   TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.evento_temporada     TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.paquete_promocional  TO 'app_gerencia';
GRANT INSERT, UPDATE ON hotel_alpheus.detalle_paquete_promocional TO 'app_gerencia';

GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_registrar_reserva        TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_verificar_disponibilidad TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_cambiar_estado_habitacion TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_checkout_rapido          TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_registrar_servicio       TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_cancelar_reserva         TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_actualizar_cliente_vip   TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_listar_hospedados        TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_reporte_ingresos_mes     TO 'app_gerencia';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_upgrade_vip              TO 'app_gerencia';


-- 3.5 app_reportes
-- Analitica/BI. Solo lectura, sin acceso a columnas sensibles. Usa
-- vistas para evitar leakage de salarios y hashes.
GRANT SELECT ON hotel_alpheus.reservacion                TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.reservacion_habitacion     TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.estancia                   TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.cancelacion                TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.cuenta                     TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.detalle_cuenta             TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.factura                    TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.pago                       TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.consumo_servicio           TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.huesped                    TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.huesped_facturador         TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.cliente_vip                TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.habitacion                 TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.categoria_habitacion       TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.servicio                   TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.tipo_servicio              TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.evento_temporada           TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.paquete_promocional        TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.detalle_paquete_promocional TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.bitacora_habitacion        TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.queja                      TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.satisfaccion               TO 'app_reportes';
GRANT SELECT ON hotel_alpheus.empleado_publico           TO 'app_reportes';

GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_listar_hospedados    TO 'app_reportes';
GRANT EXECUTE ON PROCEDURE hotel_alpheus.sp_reporte_ingresos_mes TO 'app_reportes';


-- 3.6 app_aplicacion
-- Cuenta de servicio para el backend de la aplicacion (API web/movil).
GRANT SELECT, INSERT, UPDATE, DELETE ON hotel_alpheus.* TO 'app_aplicacion';
GRANT EXECUTE                       ON hotel_alpheus.* TO 'app_aplicacion';


-- 4.1 Administrador
CREATE USER 'alpheus_admin'@'localhost'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Admin!2026.Local';
CREATE USER 'alpheus_admin'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Admin!2026.Remote';

-- 4.2 Recepcion 
CREATE USER 'rec_carla'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Rec!2026.Carla';
CREATE USER 'rec_marco'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Rec!2026.Marco';

-- 4.3 Finanzas
CREATE USER 'fin_lorena'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Fin!2026.Lorena';

-- 4.4 Gerencia
CREATE USER 'ger_alejandro'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Ger!2026.Alex';

-- 4.5 Reportes
CREATE USER 'rep_diana'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Rep!2026.Diana';

-- 4.6 Cuenta de servicio para la aplicacion (backend)
CREATE USER 'svc_app'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Svc!2026.AppBackend';


GRANT 'app_admin'      TO 'alpheus_admin'@'localhost';
GRANT 'app_admin'      TO 'alpheus_admin'@'%';
GRANT 'app_recepcion'  TO 'rec_carla'@'%';
GRANT 'app_recepcion'  TO 'rec_marco'@'%';
GRANT 'app_finanzas'   TO 'fin_lorena'@'%';
GRANT 'app_gerencia'   TO 'ger_alejandro'@'%';
GRANT 'app_reportes'   TO 'rep_diana'@'%';
GRANT 'app_aplicacion' TO 'svc_app'@'%';

SET DEFAULT ROLE 'app_admin'      TO 'alpheus_admin'@'localhost';
SET DEFAULT ROLE 'app_admin'      TO 'alpheus_admin'@'%';
SET DEFAULT ROLE 'app_recepcion'  TO 'rec_carla'@'%';
SET DEFAULT ROLE 'app_recepcion'  TO 'rec_marco'@'%';
SET DEFAULT ROLE 'app_finanzas'   TO 'fin_lorena'@'%';
SET DEFAULT ROLE 'app_gerencia'   TO 'ger_alejandro'@'%';
SET DEFAULT ROLE 'app_reportes'   TO 'rep_diana'@'%';
SET DEFAULT ROLE 'app_aplicacion' TO 'svc_app'@'%';


ALTER USER 'alpheus_admin'@'localhost' PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'alpheus_admin'@'%'         PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'rec_carla'@'%'             PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'rec_marco'@'%'             PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'fin_lorena'@'%'            PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'ger_alejandro'@'%'         PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'rep_diana'@'%'             PASSWORD EXPIRE INTERVAL 90 DAY;
ALTER USER 'svc_app'@'%'               PASSWORD EXPIRE NEVER;

-- Limites para evitar abuso (cuotas por hora a nivel cuenta).
-- Se aplican a usuarios concretos: los roles no se conectan y los
-- contadores son por sesion activa.
ALTER USER 'rep_diana'@'%'             WITH MAX_QUERIES_PER_HOUR 5000;
ALTER USER 'rep_diana'@'%'             WITH MAX_CONNECTIONS_PER_HOUR 100;
ALTER USER 'svc_app'@'%'               WITH MAX_USER_CONNECTIONS 50;


REVOKE INSERT ON hotel_alpheus.cancelacion FROM 'app_recepcion';
FLUSH PRIVILEGES;



-- Catalogo de roles, usuarios y privilegios 
SELECT user AS role_name, host
FROM mysql.user
WHERE authentication_string = '' 
  AND user LIKE 'app\_%' ESCAPE '\\';

-- Usuarios creados y a que roles pertenecen:
SELECT FROM_USER, FROM_HOST, TO_USER, TO_HOST
FROM mysql.role_edges
WHERE TO_USER IN ('alpheus_admin','rec_carla','rec_marco',
                  'fin_lorena','ger_alejandro','rep_diana','svc_app')
ORDER BY TO_USER;

-- Privilegios efectivos por usuario:
SHOW GRANTS FOR 'alpheus_admin'@'localhost';
SHOW GRANTS FOR 'rec_carla'@'%'      USING 'app_recepcion';
SHOW GRANTS FOR 'fin_lorena'@'%'     USING 'app_finanzas';
SHOW GRANTS FOR 'ger_alejandro'@'%'  USING 'app_gerencia';
SHOW GRANTS FOR 'rep_diana'@'%'      USING 'app_reportes';
SHOW GRANTS FOR 'svc_app'@'%'        USING 'app_aplicacion';

-- Privilegios del rol en si mismo (util para auditoria):
SHOW GRANTS FOR 'app_recepcion';
SHOW GRANTS FOR 'app_finanzas';
SHOW GRANTS FOR 'app_gerencia';
SHOW GRANTS FOR 'app_reportes';



