-- ============================================================
-- SISTEMA AUTÓNOMO DE GESTIÓN PARA TIENDA DE ROPA
-- Base de Datos — PostgreSQL
-- CUCEI | Ingeniería de Software | Calendario 2026A
-- ============================================================
-- Cubre: RF-01 a RF-10
-- Roles: Administrador, Vendedor, Almacenista
-- ============================================================

-- Extensión recomendada para UUIDs (opcional)
-- CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- RF-08: MÓDULO DE AUTENTICACIÓN Y ROLES
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id_rol         SERIAL          PRIMARY KEY,
    nombre         VARCHAR(50)     NOT NULL UNIQUE,  -- 'Administrador', 'Vendedor', 'Almacenista'
    descripcion    TEXT,
    activo         BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP       NOT NULL DEFAULT NOW()
);

INSERT INTO roles (nombre, descripcion) VALUES
    ('Administrador', 'Acceso total al sistema: usuarios, precios, auditoría y reportes'),
    ('Vendedor',      'Registra ventas, clientes y pagos'),
    ('Almacenista',   'Gestiona productos, inventario y proveedores');

CREATE TABLE IF NOT EXISTS usuarios (
    id_usuario     SERIAL          PRIMARY KEY,
    nombre         VARCHAR(100)    NOT NULL,
    apellido       VARCHAR(100)    NOT NULL,
    nombre_usuario VARCHAR(50)     NOT NULL UNIQUE,
    contrasena     TEXT            NOT NULL,  -- hash almacenado, nunca texto plano
    id_rol         INTEGER         NOT NULL,
    activo         BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP       NOT NULL DEFAULT NOW(),
    ultimo_acceso  TIMESTAMP,
    CONSTRAINT fk_usuarios_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
);

CREATE INDEX idx_usuarios_nombre_usuario ON usuarios(nombre_usuario);

-- ============================================================
-- RF-01: GESTIÓN DE PRODUCTOS
-- ============================================================

CREATE TABLE IF NOT EXISTS categorias (
    id_categoria   SERIAL          PRIMARY KEY,
    nombre         VARCHAR(100)    NOT NULL UNIQUE,
    descripcion    TEXT,
    activo         BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_creacion TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE TYPE genero_enum AS ENUM ('Hombre', 'Mujer', 'Unisex', 'Niño', 'Niña');

CREATE TABLE IF NOT EXISTS productos (
    id_producto        SERIAL          PRIMARY KEY,
    codigo             VARCHAR(50)     NOT NULL UNIQUE,    -- código interno / SKU
    nombre             VARCHAR(150)    NOT NULL,
    descripcion        TEXT,
    id_categoria       INTEGER,
    talla              VARCHAR(10),                        -- 'XS','S','M','L','XL','XXL', etc.
    color              VARCHAR(50),
    genero             genero_enum,
    precio_compra      NUMERIC(12,2)   NOT NULL DEFAULT 0,
    precio_venta       NUMERIC(12,2)   NOT NULL DEFAULT 0,
    imagen             BYTEA,                              -- foto opcional del producto
    activo             BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_creacion     TIMESTAMP       NOT NULL DEFAULT NOW(),
    fecha_modificacion TIMESTAMP,
    CONSTRAINT fk_productos_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);

CREATE INDEX idx_productos_codigo    ON productos(codigo);
CREATE INDEX idx_productos_categoria ON productos(id_categoria);
CREATE INDEX idx_productos_nombre    ON productos(nombre);

-- ============================================================
-- RF-02: ACTUALIZACIÓN DE INVENTARIO
-- ============================================================

CREATE TYPE tipo_movimiento_enum AS ENUM ('ENTRADA', 'SALIDA', 'AJUSTE', 'DEVOLUCION');

CREATE TABLE IF NOT EXISTS inventario (
    id_inventario       SERIAL      PRIMARY KEY,
    id_producto         INTEGER     NOT NULL UNIQUE,
    cantidad            INTEGER     NOT NULL DEFAULT 0 CHECK (cantidad >= 0),
    stock_minimo        INTEGER     NOT NULL DEFAULT 5,
    ubicacion           VARCHAR(100),
    fecha_actualizacion TIMESTAMP   NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_inventario_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

CREATE TABLE IF NOT EXISTS movimientos_inventario (
    id_movimiento     SERIAL                  PRIMARY KEY,
    id_producto       INTEGER                 NOT NULL,
    tipo              tipo_movimiento_enum    NOT NULL,
    cantidad          INTEGER                 NOT NULL,
    cantidad_anterior INTEGER                 NOT NULL,
    cantidad_nueva    INTEGER                 NOT NULL,
    motivo            TEXT,
    id_usuario        INTEGER                 NOT NULL,
    fecha             TIMESTAMP               NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_movimientos_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT fk_movimientos_usuario  FOREIGN KEY (id_usuario)  REFERENCES usuarios(id_usuario)
);

CREATE INDEX idx_movimientos_producto ON movimientos_inventario(id_producto);
CREATE INDEX idx_movimientos_fecha    ON movimientos_inventario(fecha);

-- ============================================================
-- RF-03: MÓDULO DE OFERTAS Y DESCUENTOS
-- ============================================================

CREATE TYPE tipo_descuento_enum AS ENUM ('PORCENTAJE', 'MONTO_FIJO');

CREATE TABLE IF NOT EXISTS ofertas (
    id_oferta        SERIAL               PRIMARY KEY,
    nombre           VARCHAR(150)         NOT NULL,
    descripcion      TEXT,
    tipo_descuento   tipo_descuento_enum  NOT NULL,
    valor_descuento  NUMERIC(12,2)        NOT NULL CHECK (valor_descuento > 0),
    fecha_inicio     DATE                 NOT NULL,
    fecha_fin        DATE                 NOT NULL,
    activo           BOOLEAN              NOT NULL DEFAULT TRUE,
    id_usuario_creo  INTEGER              NOT NULL,
    fecha_creacion   TIMESTAMP            NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_ofertas_usuario  FOREIGN KEY (id_usuario_creo) REFERENCES usuarios(id_usuario),
    CONSTRAINT chk_fechas_oferta   CHECK (fecha_fin >= fecha_inicio)
);

-- Relación muchos-a-muchos: una oferta puede aplicar a varios productos
CREATE TABLE IF NOT EXISTS ofertas_productos (
    id_oferta_producto SERIAL  PRIMARY KEY,
    id_oferta          INTEGER NOT NULL,
    id_producto        INTEGER NOT NULL,
    UNIQUE (id_oferta, id_producto),
    CONSTRAINT fk_op_oferta   FOREIGN KEY (id_oferta)   REFERENCES ofertas(id_oferta),
    CONSTRAINT fk_op_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- Una oferta también puede aplicar a categorías completas
CREATE TABLE IF NOT EXISTS ofertas_categorias (
    id_oferta_categoria SERIAL  PRIMARY KEY,
    id_oferta           INTEGER NOT NULL,
    id_categoria        INTEGER NOT NULL,
    UNIQUE (id_oferta, id_categoria),
    CONSTRAINT fk_oc_oferta    FOREIGN KEY (id_oferta)    REFERENCES ofertas(id_oferta),
    CONSTRAINT fk_oc_categoria FOREIGN KEY (id_categoria) REFERENCES categorias(id_categoria)
);

-- ============================================================
-- RF-04: REGISTRO DE CLIENTES
-- ============================================================

CREATE TABLE IF NOT EXISTS clientes (
    id_cliente     SERIAL          PRIMARY KEY,
    nombre         VARCHAR(100)    NOT NULL,
    apellido       VARCHAR(100)    NOT NULL,
    telefono       VARCHAR(20),
    email          VARCHAR(150),
    direccion      TEXT,
    notas          TEXT,
    activo         BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_registro TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_clientes_nombre ON clientes(nombre, apellido);

-- ============================================================
-- RF-05: MÓDULO DE VENTAS Y PAGOS
-- ============================================================

CREATE TYPE metodo_pago_enum    AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA', 'OTRO');
CREATE TYPE estado_venta_enum   AS ENUM ('COMPLETADA', 'CANCELADA', 'PENDIENTE');

CREATE TABLE IF NOT EXISTS ventas (
    id_venta        SERIAL              PRIMARY KEY,
    folio           VARCHAR(30)         NOT NULL UNIQUE,     -- ej: V-20260401-001
    id_cliente      INTEGER,                                 -- NULL = venta al público general
    id_usuario      INTEGER             NOT NULL,
    subtotal        NUMERIC(12,2)       NOT NULL DEFAULT 0,
    descuento_total NUMERIC(12,2)       NOT NULL DEFAULT 0,
    impuesto        NUMERIC(12,2)       NOT NULL DEFAULT 0,
    total           NUMERIC(12,2)       NOT NULL DEFAULT 0,
    metodo_pago     metodo_pago_enum    NOT NULL,
    estado          estado_venta_enum   NOT NULL DEFAULT 'COMPLETADA',
    observaciones   TEXT,
    fecha_venta     TIMESTAMP           NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_ventas_cliente  FOREIGN KEY (id_cliente) REFERENCES clientes(id_cliente),
    CONSTRAINT fk_ventas_usuario  FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE INDEX idx_ventas_fecha   ON ventas(fecha_venta);
CREATE INDEX idx_ventas_cliente ON ventas(id_cliente);
CREATE INDEX idx_ventas_folio   ON ventas(folio);

CREATE TABLE IF NOT EXISTS detalle_ventas (
    id_detalle      SERIAL          PRIMARY KEY,
    id_venta        INTEGER         NOT NULL,
    id_producto     INTEGER         NOT NULL,
    cantidad        INTEGER         NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2)   NOT NULL,
    id_oferta       INTEGER,
    descuento       NUMERIC(12,2)   NOT NULL DEFAULT 0,
    subtotal        NUMERIC(12,2)   NOT NULL,
    CONSTRAINT fk_dv_venta    FOREIGN KEY (id_venta)    REFERENCES ventas(id_venta),
    CONSTRAINT fk_dv_producto FOREIGN KEY (id_producto) REFERENCES productos(id_producto),
    CONSTRAINT fk_dv_oferta   FOREIGN KEY (id_oferta)   REFERENCES ofertas(id_oferta)
);

CREATE INDEX idx_detalle_venta    ON detalle_ventas(id_venta);
CREATE INDEX idx_detalle_producto ON detalle_ventas(id_producto);

-- Tabla de pagos (soporta pagos parciales o múltiples métodos)
CREATE TABLE IF NOT EXISTS pagos (
    id_pago     SERIAL              PRIMARY KEY,
    id_venta    INTEGER             NOT NULL,
    monto       NUMERIC(12,2)       NOT NULL CHECK (monto > 0),
    metodo_pago metodo_pago_enum    NOT NULL,
    referencia  VARCHAR(100),
    fecha_pago  TIMESTAMP           NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_pagos_venta FOREIGN KEY (id_venta) REFERENCES ventas(id_venta)
);

-- ============================================================
-- RF-06: GESTIÓN DE PROVEEDORES
-- ============================================================

CREATE TABLE IF NOT EXISTS proveedores (
    id_proveedor   SERIAL          PRIMARY KEY,
    nombre         VARCHAR(150)    NOT NULL,
    contacto       VARCHAR(100),
    telefono       VARCHAR(20),
    email          VARCHAR(150),
    direccion      TEXT,
    rfc            VARCHAR(20),
    notas          TEXT,
    activo         BOOLEAN         NOT NULL DEFAULT TRUE,
    fecha_registro TIMESTAMP       NOT NULL DEFAULT NOW()
);

-- Relación muchos-a-muchos: un proveedor puede surtir varios productos
CREATE TABLE IF NOT EXISTS proveedores_productos (
    id_proveedor_producto SERIAL          PRIMARY KEY,
    id_proveedor          INTEGER         NOT NULL,
    id_producto           INTEGER         NOT NULL,
    precio_proveedor      NUMERIC(12,2),
    tiempo_entrega_dias   INTEGER,
    UNIQUE (id_proveedor, id_producto),
    CONSTRAINT fk_pp_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor),
    CONSTRAINT fk_pp_producto  FOREIGN KEY (id_producto)  REFERENCES productos(id_producto)
);

-- Órdenes de compra a proveedores
CREATE TYPE estado_orden_enum AS ENUM ('PENDIENTE', 'RECIBIDA', 'CANCELADA');

CREATE TABLE IF NOT EXISTS ordenes_compra (
    id_orden        SERIAL              PRIMARY KEY,
    id_proveedor    INTEGER             NOT NULL,
    id_usuario      INTEGER             NOT NULL,
    estado          estado_orden_enum   NOT NULL DEFAULT 'PENDIENTE',
    total           NUMERIC(12,2)       NOT NULL DEFAULT 0,
    observaciones   TEXT,
    fecha_orden     TIMESTAMP           NOT NULL DEFAULT NOW(),
    fecha_recepcion TIMESTAMP,
    CONSTRAINT fk_oc_proveedor FOREIGN KEY (id_proveedor) REFERENCES proveedores(id_proveedor),
    CONSTRAINT fk_oc_usuario   FOREIGN KEY (id_usuario)   REFERENCES usuarios(id_usuario)
);

CREATE TABLE IF NOT EXISTS detalle_ordenes_compra (
    id_detalle      SERIAL          PRIMARY KEY,
    id_orden        INTEGER         NOT NULL,
    id_producto     INTEGER         NOT NULL,
    cantidad        INTEGER         NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(12,2)   NOT NULL,
    subtotal        NUMERIC(12,2)   NOT NULL,
    CONSTRAINT fk_doc_orden   FOREIGN KEY (id_orden)    REFERENCES ordenes_compra(id_orden),
    CONSTRAINT fk_doc_product FOREIGN KEY (id_producto) REFERENCES productos(id_producto)
);

-- ============================================================
-- RF-07: CONSULTAS Y REPORTES
-- ============================================================

-- Vista: productos con stock bajo
CREATE OR REPLACE VIEW vw_stock_bajo AS
SELECT
    p.id_producto,
    p.codigo,
    p.nombre,
    p.talla,
    p.color,
    i.cantidad,
    i.stock_minimo,
    i.ubicacion
FROM productos p
JOIN inventario i ON p.id_producto = i.id_producto
WHERE i.cantidad <= i.stock_minimo
  AND p.activo = TRUE;

-- Vista: resumen de ventas por día
CREATE OR REPLACE VIEW vw_ventas_diarias AS
SELECT
    v.fecha_venta::DATE     AS fecha,
    COUNT(v.id_venta)       AS total_ventas,
    SUM(v.total)            AS ingreso_total,
    SUM(v.descuento_total)  AS descuentos_total
FROM ventas v
WHERE v.estado = 'COMPLETADA'
GROUP BY v.fecha_venta::DATE;

-- Vista: ventas por vendedor
CREATE OR REPLACE VIEW vw_ventas_por_vendedor AS
SELECT
    u.id_usuario,
    u.nombre || ' ' || u.apellido AS vendedor,
    COUNT(v.id_venta)              AS num_ventas,
    SUM(v.total)                   AS total_vendido
FROM ventas v
JOIN usuarios u ON v.id_usuario = u.id_usuario
WHERE v.estado = 'COMPLETADA'
GROUP BY u.id_usuario, u.nombre, u.apellido;

-- Vista: productos más vendidos
CREATE OR REPLACE VIEW vw_productos_mas_vendidos AS
SELECT
    p.id_producto,
    p.codigo,
    p.nombre,
    p.talla,
    p.color,
    SUM(dv.cantidad) AS unidades_vendidas,
    SUM(dv.subtotal) AS ingreso_generado
FROM detalle_ventas dv
JOIN productos p ON dv.id_producto = p.id_producto
JOIN ventas v    ON dv.id_venta    = v.id_venta
WHERE v.estado = 'COMPLETADA'
GROUP BY p.id_producto, p.codigo, p.nombre, p.talla, p.color
ORDER BY unidades_vendidas DESC;

-- Vista: historial de compras por cliente
CREATE OR REPLACE VIEW vw_historial_cliente AS
SELECT
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS cliente,
    v.folio,
    v.total,
    v.metodo_pago,
    v.fecha_venta
FROM ventas v
JOIN clientes c ON v.id_cliente = c.id_cliente
WHERE v.estado = 'COMPLETADA'
ORDER BY v.fecha_venta DESC;

-- ============================================================
-- RF-09 / RF-10: LOG DE AUDITORÍA
-- ============================================================

CREATE TYPE accion_auditoria_enum AS ENUM ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'ERROR');

CREATE TABLE IF NOT EXISTS log_auditoria (
    id_log           SERIAL                  PRIMARY KEY,
    id_usuario       INTEGER,
    accion           accion_auditoria_enum   NOT NULL,
    tabla_afectada   VARCHAR(100),
    registro_id      INTEGER,
    datos_anteriores JSONB,                              -- JSONB para consultas eficientes
    datos_nuevos     JSONB,
    ip_local         VARCHAR(45),
    fecha            TIMESTAMP               NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_log_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario)
);

CREATE INDEX idx_log_usuario ON log_auditoria(id_usuario);
CREATE INDEX idx_log_fecha   ON log_auditoria(fecha);
CREATE INDEX idx_log_accion  ON log_auditoria(accion);
CREATE INDEX idx_log_tabla   ON log_auditoria(tabla_afectada);
-- Índice GIN para búsquedas eficientes dentro del JSONB
CREATE INDEX idx_log_datos_nuevos     ON log_auditoria USING GIN (datos_nuevos);
CREATE INDEX idx_log_datos_anteriores ON log_auditoria USING GIN (datos_anteriores);

-- ============================================================
-- RF-08 (complemento): PERMISOS POR ROL
-- ============================================================

CREATE TABLE IF NOT EXISTS permisos (
    id_permiso     SERIAL          PRIMARY KEY,
    id_rol         INTEGER         NOT NULL,
    modulo         VARCHAR(50)     NOT NULL,
    puede_leer     BOOLEAN         NOT NULL DEFAULT FALSE,
    puede_crear    BOOLEAN         NOT NULL DEFAULT FALSE,
    puede_editar   BOOLEAN         NOT NULL DEFAULT FALSE,
    puede_eliminar BOOLEAN         NOT NULL DEFAULT FALSE,
    UNIQUE (id_rol, modulo),
    CONSTRAINT fk_permisos_rol FOREIGN KEY (id_rol) REFERENCES roles(id_rol)
);

-- Permisos: Administrador (acceso total)
INSERT INTO permisos (id_rol, modulo, puede_leer, puede_crear, puede_editar, puede_eliminar) VALUES
    (1, 'productos',    TRUE, TRUE, TRUE, TRUE),
    (1, 'inventario',   TRUE, TRUE, TRUE, TRUE),
    (1, 'ventas',       TRUE, TRUE, TRUE, TRUE),
    (1, 'clientes',     TRUE, TRUE, TRUE, TRUE),
    (1, 'proveedores',  TRUE, TRUE, TRUE, TRUE),
    (1, 'ofertas',      TRUE, TRUE, TRUE, TRUE),
    (1, 'reportes',     TRUE, TRUE, TRUE, TRUE),
    (1, 'usuarios',     TRUE, TRUE, TRUE, TRUE),
    (1, 'auditoria',    TRUE, FALSE, FALSE, FALSE);

-- Permisos: Vendedor
INSERT INTO permisos (id_rol, modulo, puede_leer, puede_crear, puede_editar, puede_eliminar) VALUES
    (2, 'productos',    TRUE,  FALSE, FALSE, FALSE),
    (2, 'inventario',   TRUE,  FALSE, FALSE, FALSE),
    (2, 'ventas',       TRUE,  TRUE,  TRUE,  FALSE),
    (2, 'clientes',     TRUE,  TRUE,  TRUE,  FALSE),
    (2, 'proveedores',  FALSE, FALSE, FALSE, FALSE),
    (2, 'ofertas',      TRUE,  FALSE, FALSE, FALSE),
    (2, 'reportes',     TRUE,  FALSE, FALSE, FALSE),
    (2, 'usuarios',     FALSE, FALSE, FALSE, FALSE),
    (2, 'auditoria',    FALSE, FALSE, FALSE, FALSE);

-- Permisos: Almacenista
INSERT INTO permisos (id_rol, modulo, puede_leer, puede_crear, puede_editar, puede_eliminar) VALUES
    (3, 'productos',    TRUE,  TRUE,  TRUE,  FALSE),
    (3, 'inventario',   TRUE,  TRUE,  TRUE,  FALSE),
    (3, 'ventas',       FALSE, FALSE, FALSE, FALSE),
    (3, 'clientes',     FALSE, FALSE, FALSE, FALSE),
    (3, 'proveedores',  TRUE,  TRUE,  TRUE,  FALSE),
    (3, 'ofertas',      TRUE,  FALSE, FALSE, FALSE),
    (3, 'reportes',     TRUE,  FALSE, FALSE, FALSE),
    (3, 'usuarios',     FALSE, FALSE, FALSE, FALSE),
    (3, 'auditoria',    FALSE, FALSE, FALSE, FALSE);

-- ============================================================
-- FUNCIONES DE AUDITORÍA
-- En PostgreSQL los triggers requieren una función separada
-- ============================================================

-- Función genérica para registrar auditoría desde triggers
CREATE OR REPLACE FUNCTION fn_audit_log(
    p_id_usuario     INTEGER,
    p_accion         accion_auditoria_enum,
    p_tabla          TEXT,
    p_registro_id    INTEGER,
    p_datos_ant      JSONB,
    p_datos_nuevos   JSONB
) RETURNS VOID AS $$
BEGIN
    INSERT INTO log_auditoria (id_usuario, accion, tabla_afectada, registro_id, datos_anteriores, datos_nuevos)
    VALUES (p_id_usuario, p_accion, p_tabla, p_registro_id, p_datos_ant, p_datos_nuevos);
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGERS DE AUDITORÍA AUTOMÁTICA
-- ============================================================

-- Auditoría al insertar una venta
CREATE OR REPLACE FUNCTION trg_fn_audit_venta_insert()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM fn_audit_log(
        NEW.id_usuario,
        'INSERT',
        'ventas',
        NEW.id_venta,
        NULL,
        jsonb_build_object(
            'folio',       NEW.folio,
            'id_cliente',  NEW.id_cliente,
            'total',       NEW.total,
            'metodo_pago', NEW.metodo_pago::TEXT,
            'estado',      NEW.estado::TEXT
        )
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_venta_insert
AFTER INSERT ON ventas
FOR EACH ROW EXECUTE FUNCTION trg_fn_audit_venta_insert();

-- Auditoría al cancelar una venta
CREATE OR REPLACE FUNCTION trg_fn_audit_venta_cancel()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado = 'CANCELADA' AND OLD.estado <> 'CANCELADA' THEN
        PERFORM fn_audit_log(
            NEW.id_usuario,
            'UPDATE',
            'ventas',
            NEW.id_venta,
            jsonb_build_object('estado', OLD.estado::TEXT),
            jsonb_build_object('estado', NEW.estado::TEXT)
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_venta_cancel
AFTER UPDATE OF estado ON ventas
FOR EACH ROW EXECUTE FUNCTION trg_fn_audit_venta_cancel();

-- Auditoría al modificar inventario
CREATE OR REPLACE FUNCTION trg_fn_audit_inventario_update()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM fn_audit_log(
        NULL,
        'UPDATE',
        'inventario',
        NEW.id_inventario,
        jsonb_build_object('cantidad', OLD.cantidad),
        jsonb_build_object('cantidad', NEW.cantidad)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_inventario_update
AFTER UPDATE OF cantidad ON inventario
FOR EACH ROW EXECUTE FUNCTION trg_fn_audit_inventario_update();

-- Auditoría al modificar precio de producto
CREATE OR REPLACE FUNCTION trg_fn_audit_producto_precio()
RETURNS TRIGGER AS $$
BEGIN
    PERFORM fn_audit_log(
        NULL,
        'UPDATE',
        'productos',
        NEW.id_producto,
        jsonb_build_object('precio_venta', OLD.precio_venta),
        jsonb_build_object('precio_venta', NEW.precio_venta)
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_producto_precio
AFTER UPDATE OF precio_venta ON productos
FOR EACH ROW EXECUTE FUNCTION trg_fn_audit_producto_precio();

-- Descontar inventario automáticamente al registrar un detalle de venta
CREATE OR REPLACE FUNCTION trg_fn_descontar_inventario()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE inventario
    SET cantidad            = cantidad - NEW.cantidad,
        fecha_actualizacion = NOW()
    WHERE id_producto = NEW.id_producto;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_descontar_inventario
AFTER INSERT ON detalle_ventas
FOR EACH ROW EXECUTE FUNCTION trg_fn_descontar_inventario();

-- ============================================================
-- DATOS DE EJEMPLO (usuario admin inicial)
-- ============================================================

INSERT INTO usuarios (nombre, apellido, nombre_usuario, contrasena, id_rol)
VALUES ('Admin', 'Sistema', 'admin', 'CAMBIAR_POR_HASH_SEGURO', 1);

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================