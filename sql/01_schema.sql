-- Hotel Alpheus - Schema (DDL)
-- Autores: Denzel Uriarte (34684), Jorge Lopez (34323), Oscar Medina (34204)
-- Profesor: Ricardo Martinez


DROP DATABASE IF EXISTS hotel_alpheus;
CREATE DATABASE hotel_alpheus
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE hotel_alpheus;

CREATE TABLE huesped (
  id_huesped       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombres          VARCHAR(80)  NOT NULL,
  apellidos        VARCHAR(80)  NOT NULL,
  fecha_nacimiento DATE         NOT NULL,
  email            VARCHAR(120) NULL,
  pais_origen      VARCHAR(60)  NULL,
  sexo             CHAR(1)      NOT NULL,
  CONSTRAINT chk_huesped_sexo CHECK (sexo IN ('M','F','O'))
) ENGINE=InnoDB;

CREATE TABLE usuario (
  id_usuario INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  email      VARCHAR(120) NOT NULL UNIQUE,
  -- Almacenar hash
  password   VARCHAR(255) NOT NULL,
  rol        VARCHAR(30)  NOT NULL,
  CONSTRAINT chk_usuario_rol CHECK (rol IN ('admin','recepcion','finanzas','gerencia','reportes'))
) ENGINE=InnoDB;

CREATE TABLE empleado (
  id_empleado  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombres      VARCHAR(80)   NOT NULL,
  apellidos    VARCHAR(80)   NOT NULL,
  rol          VARCHAR(40)   NOT NULL,
  telefono     VARCHAR(20)   NULL,
  salario      DECIMAL(12,2) NOT NULL,
  bono         DECIMAL(12,2) NOT NULL DEFAULT 0,
  activo       BOOLEAN       NOT NULL DEFAULT TRUE,
  departamento VARCHAR(40)   NOT NULL,
  CONSTRAINT chk_empleado_salario CHECK (salario >= 0),
  CONSTRAINT chk_empleado_bono    CHECK (bono    >= 0)
) ENGINE=InnoDB;

CREATE TABLE categoria_habitacion (
  id_categoria INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre       VARCHAR(60)   NOT NULL UNIQUE,
  descripcion  VARCHAR(255)  NULL,
  precio_base  DECIMAL(12,2) NOT NULL,
  CONSTRAINT chk_categoria_precio CHECK (precio_base > 0)
) ENGINE=InnoDB;

CREATE TABLE evento_temporada (
  id_evento     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre_evento VARCHAR(80) NOT NULL,
  fecha_inicio  DATE        NOT NULL,
  fecha_fin     DATE        NOT NULL,
  CONSTRAINT chk_evento_fechas CHECK (fecha_fin >= fecha_inicio)
) ENGINE=InnoDB;


CREATE TABLE tipo_servicio (
  id_tipo_servicio INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nombre           VARCHAR(60) NOT NULL UNIQUE,
  -- Origen del servicio: 'interno' (spa, gym, restaurante, casino)
  --                       'externo' (tours, museos, traslados)
  categoria        VARCHAR(20) NOT NULL,
  CONSTRAINT chk_tipo_servicio_categoria CHECK (categoria IN ('interno','externo'))
) ENGINE=InnoDB;


CREATE TABLE huesped_facturador (
  id_huesped_facturador INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_huesped            INT UNSIGNED NOT NULL UNIQUE,
  direccion             VARCHAR(200) NOT NULL,
  telefono_casa         VARCHAR(20)  NULL,
  telefono_celular      VARCHAR(20)  NOT NULL,
  email                 VARCHAR(120) NOT NULL UNIQUE,
  rfc                   VARCHAR(13)  NOT NULL UNIQUE,
  procedencia           VARCHAR(80)  NULL,
  numero_reservas       INT UNSIGNED NOT NULL DEFAULT 0,
  CONSTRAINT fk_hf_huesped FOREIGN KEY (id_huesped)
    REFERENCES huesped(id_huesped) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cliente_vip (
  id_vip                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_huesped_facturador INT UNSIGNED NOT NULL UNIQUE,
  nivel_vip             VARCHAR(20)  NOT NULL DEFAULT 'bronce',
  puntos_acumulados     INT UNSIGNED NOT NULL DEFAULT 0,
  contador_reservas     INT UNSIGNED NOT NULL DEFAULT 0,
  fecha_registro        DATE         NOT NULL,
  CONSTRAINT chk_vip_nivel CHECK (nivel_vip IN ('bronce','plata','oro','platino')),
  CONSTRAINT fk_vip_hf FOREIGN KEY (id_huesped_facturador)
    REFERENCES huesped_facturador(id_huesped_facturador) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE habitacion (
  id_habitacion     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_categoria      INT UNSIGNED  NOT NULL,
  numero_habitacion VARCHAR(10)   NOT NULL UNIQUE,
  piso              INT           NOT NULL,
  precio            DECIMAL(12,2) NOT NULL,
  estado            VARCHAR(20)   NOT NULL DEFAULT 'disponible',
  CONSTRAINT chk_habitacion_precio CHECK (precio > 0),
  CONSTRAINT chk_habitacion_estado CHECK (estado IN ('disponible','ocupada','mantenimiento','limpieza','fuera_de_servicio')),
  CONSTRAINT fk_habitacion_categoria FOREIGN KEY (id_categoria)
    REFERENCES categoria_habitacion(id_categoria) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bono_empleado (
  id_bono     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_empleado INT UNSIGNED  NOT NULL,
  monto       DECIMAL(12,2) NOT NULL,
  fecha_hora  DATETIME      NOT NULL,
  motivo      VARCHAR(200)  NOT NULL,
  CONSTRAINT chk_bono_monto CHECK (monto > 0),
  CONSTRAINT fk_bono_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE paquete_promocional (
  id_paquete_promocional INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_evento              INT UNSIGNED  NOT NULL,
  descripcion            VARCHAR(255)  NOT NULL,
  precio                 DECIMAL(12,2) NOT NULL,
  inicio_validez         DATE          NOT NULL,
  fin_validez            DATE          NOT NULL,
  CONSTRAINT chk_paquete_precio CHECK (precio > 0),
  CONSTRAINT chk_paquete_fechas CHECK (fin_validez >= inicio_validez),
  CONSTRAINT fk_paquete_evento FOREIGN KEY (id_evento)
    REFERENCES evento_temporada(id_evento) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE servicio (
  id_servicio      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_tipo_servicio INT UNSIGNED  NOT NULL,
  nombre_servicio  VARCHAR(100)  NOT NULL,
  precio           DECIMAL(12,2) NOT NULL,
  disponible       BOOLEAN       NOT NULL DEFAULT TRUE,
  CONSTRAINT chk_servicio_precio CHECK (precio > 0),
  CONSTRAINT fk_servicio_tipo FOREIGN KEY (id_tipo_servicio)
    REFERENCES tipo_servicio(id_tipo_servicio) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE reservacion (
  id_reservacion        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_huesped            INT UNSIGNED  NOT NULL,
  id_huesped_facturador INT UNSIGNED  NOT NULL,
  id_usuario            INT UNSIGNED  NOT NULL,
  fecha_inicio          DATE          NOT NULL,
  fecha_salida          DATE          NOT NULL,
  estado                VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
  metodo                VARCHAR(20)   NOT NULL,
  subtotal              DECIMAL(12,2) NOT NULL DEFAULT 0,
  total                 DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT chk_reservacion_fechas CHECK (fecha_salida > fecha_inicio),
  CONSTRAINT chk_reservacion_estado CHECK (estado IN ('pendiente','confirmada','check_in','completada','cancelada','expirada')),
  CONSTRAINT chk_reservacion_metodo CHECK (metodo IN ('internet','telefono','presencial')),
  CONSTRAINT chk_reservacion_montos CHECK (subtotal >= 0 AND total >= 0),
  CONSTRAINT fk_reservacion_huesped FOREIGN KEY (id_huesped)
    REFERENCES huesped(id_huesped) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reservacion_facturador FOREIGN KEY (id_huesped_facturador)
    REFERENCES huesped_facturador(id_huesped_facturador) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_reservacion_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE reservacion_habitacion (
  id_reservacion_habitacion INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reservacion            INT UNSIGNED  NOT NULL,
  id_habitacion             INT UNSIGNED  NOT NULL,
  tarifa_por_noche          DECIMAL(12,2) NOT NULL,
  noches                    INT UNSIGNED  NOT NULL,
  cantidad_habitaciones     INT UNSIGNED  NOT NULL DEFAULT 1,
  subtotal                  DECIMAL(12,2) NOT NULL,
  CONSTRAINT chk_rh_tarifa   CHECK (tarifa_por_noche > 0),
  CONSTRAINT chk_rh_noches   CHECK (noches > 0),
  CONSTRAINT chk_rh_cantidad CHECK (cantidad_habitaciones > 0),
  CONSTRAINT chk_rh_subtotal CHECK (subtotal >= 0),
  CONSTRAINT fk_rh_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rh_habitacion FOREIGN KEY (id_habitacion)
    REFERENCES habitacion(id_habitacion) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE estancia (
  id_estancia                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reservacion                 INT UNSIGNED NOT NULL,
  id_empleado                    INT UNSIGNED NOT NULL,
  id_habitacion                  INT UNSIGNED NOT NULL,
  fecha_hora_checkin             DATETIME     NOT NULL,
  fecha_hora_checkout_programado DATETIME     NOT NULL,
  fecha_hora_checkout_real       DATETIME     NULL,
  CONSTRAINT chk_estancia_checkout_programado
    CHECK (fecha_hora_checkout_programado > fecha_hora_checkin),
  CONSTRAINT fk_estancia_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_estancia_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_estancia_habitacion FOREIGN KEY (id_habitacion)
    REFERENCES habitacion(id_habitacion) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cancelacion (
  id_cancelacion    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reservacion    INT UNSIGNED  NOT NULL UNIQUE,
  id_usuario        INT UNSIGNED  NOT NULL,
  motivo            VARCHAR(255)  NOT NULL,
  penalizacion      DECIMAL(12,2) NOT NULL DEFAULT 0,
  fecha_cancelacion DATETIME      NOT NULL,
  CONSTRAINT chk_cancelacion_penalizacion CHECK (penalizacion >= 0),
  CONSTRAINT fk_cancelacion_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_cancelacion_usuario FOREIGN KEY (id_usuario)
    REFERENCES usuario(id_usuario) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE cuenta (
  id_cuenta      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reservacion INT UNSIGNED  NOT NULL UNIQUE,
  fecha_apertura DATE          NOT NULL,
  fecha_cierre   DATE          NULL,
  subtotal       DECIMAL(12,2) NOT NULL DEFAULT 0,
  total          DECIMAL(12,2) NOT NULL DEFAULT 0,
  CONSTRAINT chk_cuenta_fechas CHECK (fecha_cierre IS NULL OR fecha_cierre >= fecha_apertura),
  CONSTRAINT chk_cuenta_montos CHECK (subtotal >= 0 AND total >= 0),
  CONSTRAINT fk_cuenta_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE detalle_cuenta (
  id_detalle_cuenta INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_cuenta         INT UNSIGNED  NOT NULL,
  tipo              VARCHAR(30)   NOT NULL,
  descripcion       VARCHAR(200)  NOT NULL,
  cantidad          DECIMAL(10,2) NOT NULL DEFAULT 1,
  precio_unitario   DECIMAL(12,2) NOT NULL,
  descuento         DECIMAL(12,2) NOT NULL DEFAULT 0,
  impuesto          DECIMAL(12,2) NOT NULL DEFAULT 0,
  importe           DECIMAL(12,2) NOT NULL,
  CONSTRAINT chk_detalle_cuenta_tipo   CHECK (tipo IN ('habitacion','servicio','paquete','ajuste')),
  CONSTRAINT chk_detalle_cuenta_montos CHECK (cantidad > 0 AND precio_unitario >= 0
                                              AND descuento >= 0 AND impuesto >= 0
                                              AND importe >= 0),
  CONSTRAINT fk_detalle_cuenta_cuenta FOREIGN KEY (id_cuenta)
    REFERENCES cuenta(id_cuenta) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE factura (
  id_factura            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_cuenta             INT UNSIGNED  NOT NULL,
  id_huesped_facturador INT UNSIGNED  NOT NULL,
  id_empleado           INT UNSIGNED  NOT NULL,
  fecha_emision         DATE          NOT NULL,
  subtotal              DECIMAL(12,2) NOT NULL,
  impuestos             DECIMAL(12,2) NOT NULL,
  total                 DECIMAL(12,2) NOT NULL,
  estado_factura        VARCHAR(20)   NOT NULL DEFAULT 'pendiente',
  CONSTRAINT chk_factura_montos CHECK (subtotal >= 0 AND impuestos >= 0 AND total >= 0),
  CONSTRAINT chk_factura_estado CHECK (estado_factura IN ('pagada','pendiente','vencida','cancelada')),
  CONSTRAINT fk_factura_cuenta FOREIGN KEY (id_cuenta)
    REFERENCES cuenta(id_cuenta) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_factura_facturador FOREIGN KEY (id_huesped_facturador)
    REFERENCES huesped_facturador(id_huesped_facturador) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_factura_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE pago (
  id_pago     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_factura  INT UNSIGNED  NOT NULL,
  fecha_pago  DATE          NOT NULL,
  monto       DECIMAL(12,2) NOT NULL,
  metodo_pago VARCHAR(30)   NOT NULL,
  referencia  VARCHAR(80)   NULL,
  estado      VARCHAR(20)   NOT NULL DEFAULT 'completado',
  CONSTRAINT chk_pago_monto  CHECK (monto > 0),
  CONSTRAINT chk_pago_metodo CHECK (metodo_pago IN ('efectivo','tarjeta_credito','tarjeta_debito','transferencia','paypal')),
  CONSTRAINT chk_pago_estado CHECK (estado IN ('completado','pendiente','fallido','reembolsado')),
  CONSTRAINT fk_pago_factura FOREIGN KEY (id_factura)
    REFERENCES factura(id_factura) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE detalle_paquete_promocional (
  id_detalle_paquete_promocional INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_paquete_promocional         INT UNSIGNED  NOT NULL,
  id_servicio                    INT UNSIGNED  NOT NULL,
  cantidad_incluida              DECIMAL(10,2) NOT NULL DEFAULT 1,
  CONSTRAINT chk_dpp_cantidad CHECK (cantidad_incluida > 0),
  CONSTRAINT uq_dpp_paquete_servicio UNIQUE (id_paquete_promocional, id_servicio),
  CONSTRAINT fk_dpp_paquete FOREIGN KEY (id_paquete_promocional)
    REFERENCES paquete_promocional(id_paquete_promocional) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_dpp_servicio FOREIGN KEY (id_servicio)
    REFERENCES servicio(id_servicio) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE consumo_servicio (
  id_consumo      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_reservacion  INT UNSIGNED  NOT NULL,
  id_huesped      INT UNSIGNED  NOT NULL,
  id_servicio     INT UNSIGNED  NOT NULL,
  id_empleado     INT UNSIGNED  NOT NULL,
  cantidad        INT UNSIGNED  NOT NULL DEFAULT 1,
  precio_unitario DECIMAL(12,2) NOT NULL,
  fecha_hora      DATETIME      NOT NULL,
  CONSTRAINT chk_consumo_cantidad CHECK (cantidad > 0),
  CONSTRAINT chk_consumo_precio   CHECK (precio_unitario > 0),
  CONSTRAINT fk_consumo_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_consumo_huesped FOREIGN KEY (id_huesped)
    REFERENCES huesped(id_huesped) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_consumo_servicio FOREIGN KEY (id_servicio)
    REFERENCES servicio(id_servicio) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_consumo_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE bitacora_habitacion (
  id_bitacora     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_habitacion   INT UNSIGNED NOT NULL,
  id_empleado     INT UNSIGNED NULL,
  id_reservacion  INT UNSIGNED NULL,
  estado_anterior VARCHAR(20)  NOT NULL,
  estado_nuevo    VARCHAR(20)  NOT NULL,
  fecha_hora      DATETIME     NOT NULL,
  CONSTRAINT fk_bitacora_habitacion FOREIGN KEY (id_habitacion)
    REFERENCES habitacion(id_habitacion) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_bitacora_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT fk_bitacora_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE queja (
  id_queja         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_huesped       INT UNSIGNED  NOT NULL,
  id_reservacion   INT UNSIGNED  NOT NULL,
  id_empleado      INT UNSIGNED  NULL,
  receptor         VARCHAR(80)   NULL,
  queja            VARCHAR(1000) NOT NULL,
  fecha_queja      DATE          NOT NULL,
  resolucion_queja VARCHAR(1000) NULL,
  fecha_resolucion DATE          NULL,
  departamento     VARCHAR(40)   NOT NULL,
  CONSTRAINT chk_queja_fechas CHECK (fecha_resolucion IS NULL OR fecha_resolucion >= fecha_queja),
  CONSTRAINT fk_queja_huesped FOREIGN KEY (id_huesped)
    REFERENCES huesped(id_huesped) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_queja_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_queja_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE satisfaccion (
  id_satisfaccion    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  id_huesped         INT UNSIGNED  NOT NULL,
  id_reservacion     INT UNSIGNED  NOT NULL,
  id_empleado        INT UNSIGNED  NULL,
  departamento       VARCHAR(40)   NOT NULL,
  receptor           VARCHAR(80)   NULL,
  comentarios        VARCHAR(1000) NULL,
  fecha_satisfaccion DATE          NOT NULL,
  calificacion       TINYINT       NOT NULL,
  CONSTRAINT chk_satisfaccion_calificacion CHECK (calificacion BETWEEN 1 AND 5),
  CONSTRAINT fk_satisfaccion_huesped FOREIGN KEY (id_huesped)
    REFERENCES huesped(id_huesped) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_satisfaccion_reservacion FOREIGN KEY (id_reservacion)
    REFERENCES reservacion(id_reservacion) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_satisfaccion_empleado FOREIGN KEY (id_empleado)
    REFERENCES empleado(id_empleado) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;
