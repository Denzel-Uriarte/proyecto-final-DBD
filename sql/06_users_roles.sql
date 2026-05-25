-- =====================================================================
-- Hotel Alpheus - Administracion de usuarios y roles (lineamiento 4a, 4d)
-- CETYS Universidad - Diseno de Bases de Datos 2026-1, Proyecto Final
-- =====================================================================
-- Cubre los puntos 4a ("Demostrar administracion de usuarios... permisos,
-- concesiones, revocaciones, privilegios, roles") y 4d ("Demostrar el uso
-- de los usuarios creados acorde a las caracteristicas establecidas").
--
-- ORDEN DE EJECUCION RECOMENDADO:
--   1) sql/01_schema.sql
--   2) sql/02_seed.sql
--   3) sql/03_triggers.sql
--   4) sql/04_procedures.sql
--   5) sql/05_views_queries.sql
--   6) sql/06_users_roles.sql   <- este archivo
--
-- REQUISITOS:
--   * MySQL 8.0+ (soporte nativo de roles, SET DEFAULT ROLE).
--   * Ejecutar como root (o cuenta con CREATE USER, GRANT OPTION, SUPER).
--
-- ESTRATEGIA:
--   * 5 roles funcionales alineados con los valores de `usuario.rol`:
--       app_admin, app_recepcion, app_finanzas, app_gerencia, app_reportes.
--   * 1 rol tecnico para el backend de aplicacion (app_aplicacion).
--   * Los privilegios se otorgan al ROL, nunca al usuario directamente.
--   * Cada usuario concreto recibe su rol via GRANT + SET DEFAULT ROLE.
--   * Columnas sensibles (empleado.salario) se enmascaran con vistas
--     dedicadas para los roles que no deben verlas.
--   * Politicas de seguridad: expiracion de contrasena, bloqueo de cuenta
--     y posibilidad de exigir TLS para conexiones externas.
-- =====================================================================

USE hotel_alpheus;

-- ---------------------------------------------------------------------
-- 0) Limpieza idempotente
--    Se borran roles y usuarios en orden inverso para no dejar
--    referencias colgadas (el usuario debe perder el rol antes de
--    poder dropear el rol).
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- 1) Creacion de roles
-- ---------------------------------------------------------------------
CREATE ROLE 'app_admin';
CREATE ROLE 'app_recepcion';
CREATE ROLE 'app_finanzas';
CREATE ROLE 'app_gerencia';
CREATE ROLE 'app_reportes';
CREATE ROLE 'app_aplicacion';


-- ---------------------------------------------------------------------
-- 2) Vistas seguras
--    Se crean ANTES de los GRANT para que los roles puedan recibir
--    privilegios sobre ellas. Estas vistas enmascaran columnas
--    sensibles (salarios, hashes de contrasena) para roles no
--    autorizados.
-- ---------------------------------------------------------------------

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


-- ---------------------------------------------------------------------
-- 3) Privilegios por rol
-- ---------------------------------------------------------------------

-- 3.1 app_admin -------------------------------------------------------
-- DBA de la base de datos: todos los privilegios dentro de hotel_alpheus
-- mas SHOW DATABASES global para diagnostico. NO se concede a nivel
-- global SUPER ni FILE: la separacion de poderes evita que un admin
-- pueda apagar el servidor o leer ficheros del SO.
GRANT ALL PRIVILEGES ON hotel_alpheus.* TO 'app_admin' WITH GRANT OPTION;
GRANT SHOW DATABASES, PROCESS ON *.* TO 'app_admin';


-- 3.2 app_recepcion ---------------------------------------------------
-- Mostrador. Crea huespedes, reservas, estancias y consumos; NO ve
-- compensaciones de empleados; NO toca facturas/pagos directamente
-- (lo hace via sp_checkout_rapido). Tampoco puede borrar.
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

-- Empleados: solo via vista publica (sin salario/bono)
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


-- 3.3 app_finanzas ----------------------------------------------------
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


-- 3.4 app_gerencia ----------------------------------------------------
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


-- 3.5 app_reportes ----------------------------------------------------
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


-- 3.6 app_aplicacion --------------------------------------------------
-- Cuenta de servicio para el backend de la aplicacion (API web/movil).
-- Acceso CRUD a todas las tablas operativas; ejecuta todos los SPs.
-- NO puede hacer DDL: la app no debe alterar la estructura.
GRANT SELECT, INSERT, UPDATE, DELETE ON hotel_alpheus.* TO 'app_aplicacion';
GRANT EXECUTE                       ON hotel_alpheus.* TO 'app_aplicacion';
-- Negar DDL implicitamente: no se otorgan CREATE/DROP/ALTER/INDEX/REFERENCES.


-- ---------------------------------------------------------------------
-- 4) Creacion de usuarios concretos
--    Convencion: <rol_corto>_<nombre>. Hosts:
--      * 'localhost' para administradores que se conectan desde el VM.
--      * '%' para usuarios que se conectan via TCP (oficina/cloud).
--    Las contrasenas son de ejemplo academico. Reemplazar antes de
--    desplegar a produccion y usar gestor de secretos (Secret Manager
--    en GCP).
-- ---------------------------------------------------------------------

-- 4.1 Administrador (acceso local + remoto)
CREATE USER 'alpheus_admin'@'localhost'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Admin!2026.Local';
CREATE USER 'alpheus_admin'@'%'
  IDENTIFIED WITH mysql_native_password BY 'Alpheus.Admin!2026.Remote';

-- 4.2 Recepcion (dos usuarios para mostrar la replicacion del rol)
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


-- ---------------------------------------------------------------------
-- 5) Asignacion de roles a usuarios + activacion por default
--    SET DEFAULT ROLE garantiza que al hacer login, los privilegios
--    del rol esten activos sin que el usuario tenga que ejecutar
--    SET ROLE manualmente.
-- ---------------------------------------------------------------------
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


-- ---------------------------------------------------------------------
-- 6) Endurecimiento (lineamiento 4a: privilegios y politicas)
--    * Expiracion de contrasena a 90 dias para usuarios humanos.
--    * Cuentas tecnicas (svc_app) no expiran para no romper el backend;
--      se rotan via deploy.
--    * Cualquier cuenta '@%' puede exigirse REQUIRE SSL para conexion
--      remota cifrada (descomentar en produccion).
-- ---------------------------------------------------------------------
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

-- Plantilla TLS (mantener comentado mientras se prueba en local):
-- ALTER USER 'alpheus_admin'@'%' REQUIRE SSL;
-- ALTER USER 'svc_app'@'%'       REQUIRE X509;


-- ---------------------------------------------------------------------
-- 7) REVOKE demostrativo (lineamiento 4a)
--    Caso de negocio: tras una auditoria interna se determina que el
--    rol de recepcion NO debe poder ABRIR cancelaciones directamente;
--    solo via el procedure sp_cancelar_reserva (que aplica la regla del
--    55% de penalizacion). Revocamos el INSERT directo sobre la tabla.
-- ---------------------------------------------------------------------
REVOKE INSERT ON hotel_alpheus.cancelacion FROM 'app_recepcion';
-- Segundo caso: reportes nunca debe ver consumos individuales por
-- huesped (PII); ya solo tiene SELECT en consumo_servicio. Si se quisiera
-- revocar por completo:
-- REVOKE SELECT ON hotel_alpheus.consumo_servicio FROM 'app_reportes';


-- ---------------------------------------------------------------------
-- 8) FLUSH PRIVILEGES (no es estrictamente necesario tras GRANT/REVOKE
--    en MySQL 8.0, pero se incluye por convencion academica)
-- ---------------------------------------------------------------------
FLUSH PRIVILEGES;


-- =====================================================================
-- 9) DEMOSTRACIONES (lineamiento 4d)
-- =====================================================================
-- Para verificar la administracion, ejecutar los siguientes bloques
-- como root o como cuenta admin. Tambien se incluyen ejemplos de lo
-- que cada usuario PUEDE y NO PUEDE hacer.

-- 9.1 Catalogo de roles, usuarios y privilegios -----------------------
-- Roles existentes:
SELECT user AS role_name, host
FROM mysql.user
WHERE authentication_string = ''  -- los roles no tienen password
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


-- 9.2 Casos de uso (ejecutar conectado como cada usuario) -------------
-- ---------------------------------------------------------------------
-- Conectarse desde shell:
--   mysql -h <host> -u rec_carla     -p hotel_alpheus
--   mysql -h <host> -u fin_lorena    -p hotel_alpheus
--   mysql -h <host> -u ger_alejandro -p hotel_alpheus
--   mysql -h <host> -u rep_diana     -p hotel_alpheus
--   mysql -h <host> -u svc_app       -p hotel_alpheus

-- 9.2.1 Como rec_carla (recepcion) ----------------------------------
-- Puede listar hospedados y registrar reservas:
--   CALL sp_listar_hospedados();
--   CALL sp_registrar_reserva(1, 1, 5, '2026-06-10', '2026-06-13',
--                              'internet', 7, @new);
--   SELECT @new;
-- NO puede ver salarios (deberia fallar con ERROR 1142):
--   SELECT salario FROM empleado WHERE id_empleado = 1;
-- SI puede ver el directorio publico de empleados:
--   SELECT * FROM empleado_publico LIMIT 5;
-- NO puede insertar directamente en cancelacion (revocado en seccion 7):
--   INSERT INTO cancelacion (...) VALUES (...);   -- ERROR 1142
-- SI puede cancelar via procedure (control de negocio):
--   CALL sp_cancelar_reserva(101, 5, 'Cliente cambio de planes', @pen);

-- 9.2.2 Como fin_lorena (finanzas) ----------------------------------
-- Puede ver el reporte mensual de ingresos:
--   CALL sp_reporte_ingresos_mes(2026, 5);
-- Puede emitir factura rapida en checkout:
--   CALL sp_checkout_rapido(105, 3, @id_factura);
-- NO puede crear nuevas reservas (no tiene EXECUTE):
--   CALL sp_registrar_reserva(...);   -- ERROR 1370

-- 9.2.3 Como ger_alejandro (gerencia) -------------------------------
-- Ve todo lo monetario y operativo, mas la auditoria:
--   SELECT * FROM bitacora_habitacion ORDER BY fecha_hora DESC LIMIT 10;
--   SELECT departamento, ROUND(AVG(calificacion),2) AS rating
--   FROM satisfaccion GROUP BY departamento;
-- Puede dar bonos a empleados destacados:
--   INSERT INTO bono_empleado (id_empleado, monto, fecha_hora, motivo)
--   VALUES (12, 1500, NOW(), 'Reconocimiento Q2');

-- 9.2.4 Como rep_diana (reportes) -----------------------------------
-- Lectura amplia, sin acceso a columnas sensibles:
--   SELECT COUNT(*) FROM reservacion WHERE estado='completada';
--   SELECT * FROM empleado_publico;    -- OK
-- NO puede ver empleado directamente:
--   SELECT * FROM empleado;            -- ERROR 1142

-- 9.2.5 Como svc_app (aplicacion) -----------------------------------
-- Backend operativo. Puede hacer cualquier operacion CRUD y ejecutar
-- procedures, pero NO DDL:
--   CALL sp_registrar_reserva(1, 1, 5, '2026-07-01', '2026-07-05',
--                             'internet', 11, @new);
--   DROP TABLE huesped;                -- ERROR 1142


-- =====================================================================
-- FIN del script de administracion de usuarios.
-- Para revertir todo:
--   FUENTE: re-ejecutar este archivo (idempotente, dropea antes de
--   crear). Para limpiar manualmente, copiar la seccion 0.
-- =====================================================================
