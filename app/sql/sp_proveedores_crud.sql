-- ============================================================================
-- SPs faltantes del módulo de Proveedores (TblProveedores)
-- Fecha: 2026-09-27
-- Compatibles con app/routes/proveedores.py:
--   sp_ObtenerProveedorPorRUC  -> 1 param   (detalle/edición)
--   sp_CrearProveedor          -> 44 params (POST /api/proveedores/crear)
--   sp_ActualizarProveedor     -> 46 params (PUT  /api/proveedores/actualizar/<ruc>)
--                                 [0] p_ruc_actual (URL) + [1] p_ruc_nuevo (formulario)
--   sp_EliminarProveedor       -> 2 params  (DELETE /api/proveedores/eliminar/<ruc>)
--
-- Cada bloque es idempotente (DROP PROCEDURE IF EXISTS antes de crear).
-- El bloque con sp_ListarProveedores ya existe y NO se modifica.
-- ============================================================================

-- @SP sp_ObtenerProveedorPorRUC
DROP PROCEDURE IF EXISTS sp_ObtenerProveedorPorRUC;
CREATE PROCEDURE sp_ObtenerProveedorPorRUC(IN p_ruc VARCHAR(11))
BEGIN
    SELECT
        p.*,
        CONCAT(IFNULL(per.nombres, ''), ' ', IFNULL(per.apellido_paterno, ''), ' ', IFNULL(per.apellido_materno, '')) AS creado_por_nombre,
        CONCAT(IFNULL(per2.nombres, ' '), ' ', IFNULL(per2.apellido_paterno, ''), ' ', IFNULL(per2.apellido_materno, '')) AS actualizado_por_nombre
    FROM TblProveedores p
    LEFT JOIN TblPersona per ON p.creado_por = per.num_documento
    LEFT JOIN TblPersona per2 ON p.actualizado_por = per2.num_documento
    WHERE p.ruc = p_ruc
      AND p.estado != 'ELIMINADO';
END

-- @SP sp_CrearProveedor
DROP PROCEDURE IF EXISTS sp_CrearProveedor;
CREATE PROCEDURE sp_CrearProveedor(
    IN p_ruc VARCHAR(11),
    IN p_razon_social VARCHAR(255),
    IN p_nombre_comercial VARCHAR(255),
    IN p_tipo_contribuyente VARCHAR(20),
    IN p_telefono VARCHAR(20),
    IN p_telefono_alternativo VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_email_facturacion VARCHAR(100),
    IN p_sitio_web VARCHAR(255),
    IN p_direccion_fiscal TEXT,
    IN p_departamento VARCHAR(100),
    IN p_provincia VARCHAR(100),
    IN p_distrito VARCHAR(100),
    IN p_ubigeo VARCHAR(6),
    IN p_referencia TEXT,
    IN p_contacto_nombre VARCHAR(255),
    IN p_contacto_cargo VARCHAR(100),
    IN p_contacto_telefono VARCHAR(20),
    IN p_contacto_email VARCHAR(100),
    IN p_contacto_dni VARCHAR(8),
    IN p_banco_1 VARCHAR(100),
    IN p_cuenta_banco_1 VARCHAR(50),
    IN p_tipo_cuenta_1 VARCHAR(20),
    IN p_moneda_1 VARCHAR(10),
    IN p_cci_1 VARCHAR(20),
    IN p_banco_2 VARCHAR(100),
    IN p_cuenta_banco_2 VARCHAR(50),
    IN p_tipo_cuenta_2 VARCHAR(20),
    IN p_moneda_2 VARCHAR(10),
    IN p_cci_2 VARCHAR(20),
    IN p_rubro_negocio VARCHAR(255),
    IN p_categoria VARCHAR(20),
    IN p_calificacion VARCHAR(20),
    IN p_condicion_pago VARCHAR(100),
    IN p_plazo_entrega VARCHAR(100),
    IN p_descuento_comercial DECIMAL(5,2),
    IN p_es_agente_retencion TINYINT(1),
    IN p_es_buen_contribuyente TINYINT(1),
    IN p_tiene_certificado_calidad TINYINT(1),
    IN p_certificados_adjuntos TEXT,
    IN p_estado VARCHAR(20),
    IN p_observaciones TEXT,
    IN p_notas_internas TEXT,
    IN p_creado_por VARCHAR(20)
)
BEGIN
    IF EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El RUC ya está registrado';
    END IF;

    INSERT INTO TblProveedores (
        ruc, razon_social, nombre_comercial, tipo_contribuyente, telefono, telefono_alternativo,
        email, email_facturacion, sitio_web, direccion_fiscal, departamento, provincia, distrito,
        ubigeo, referencia, contacto_nombre, contacto_cargo, contacto_telefono, contacto_email,
        contacto_dni, banco_1, cuenta_banco_1, tipo_cuenta_1, moneda_1, cci_1, banco_2,
        cuenta_banco_2, tipo_cuenta_2, moneda_2, cci_2, rubro_negocio, categoria, calificacion,
        condicion_pago, plazo_entrega, descuento_comercial, es_agente_retencion,
        es_buen_contribuyente, tiene_certificado_calidad, certificados_adjuntos, estado,
        observaciones, notas_internas, creado_por
    ) VALUES (
        p_ruc, p_razon_social, p_nombre_comercial, p_tipo_contribuyente, p_telefono, p_telefono_alternativo,
        p_email, p_email_facturacion, p_sitio_web, p_direccion_fiscal, p_departamento, p_provincia, p_distrito,
        p_ubigeo, p_referencia, p_contacto_nombre, p_contacto_cargo, p_contacto_telefono, p_contacto_email,
        p_contacto_dni, p_banco_1, p_cuenta_banco_1, p_tipo_cuenta_1, p_moneda_1, p_cci_1, p_banco_2,
        p_cuenta_banco_2, p_tipo_cuenta_2, p_moneda_2, p_cci_2, p_rubro_negocio, p_categoria, p_calificacion,
        p_condicion_pago, p_plazo_entrega, p_descuento_comercial, p_es_agente_retencion,
        p_es_buen_contribuyente, p_tiene_certificado_calidad, p_certificados_adjuntos, p_estado,
        p_observaciones, p_notas_internas, p_creado_por
    );

    SELECT p_ruc AS ruc, 1 AS resultado, 'Proveedor creado' AS mensaje;
END

-- @SP sp_ActualizarProveedor
DROP PROCEDURE IF EXISTS sp_ActualizarProveedor;
CREATE PROCEDURE sp_ActualizarProveedor(
    IN p_ruc_actual VARCHAR(11),
    IN p_ruc_nuevo VARCHAR(11),
    IN p_razon_social VARCHAR(255),
    IN p_nombre_comercial VARCHAR(255),
    IN p_tipo_contribuyente VARCHAR(20),
    IN p_telefono VARCHAR(20),
    IN p_telefono_alternativo VARCHAR(20),
    IN p_email VARCHAR(100),
    IN p_email_facturacion VARCHAR(100),
    IN p_sitio_web VARCHAR(255),
    IN p_direccion_fiscal TEXT,
    IN p_departamento VARCHAR(100),
    IN p_provincia VARCHAR(100),
    IN p_distrito VARCHAR(100),
    IN p_ubigeo VARCHAR(6),
    IN p_referencia TEXT,
    IN p_contacto_nombre VARCHAR(255),
    IN p_contacto_cargo VARCHAR(100),
    IN p_contacto_telefono VARCHAR(20),
    IN p_contacto_email VARCHAR(100),
    IN p_contacto_dni VARCHAR(8),
    IN p_banco_1 VARCHAR(100),
    IN p_cuenta_banco_1 VARCHAR(50),
    IN p_tipo_cuenta_1 VARCHAR(20),
    IN p_moneda_1 VARCHAR(10),
    IN p_cci_1 VARCHAR(20),
    IN p_banco_2 VARCHAR(100),
    IN p_cuenta_banco_2 VARCHAR(50),
    IN p_tipo_cuenta_2 VARCHAR(20),
    IN p_moneda_2 VARCHAR(10),
    IN p_cci_2 VARCHAR(20),
    IN p_rubro_negocio VARCHAR(255),
    IN p_categoria VARCHAR(20),
    IN p_calificacion VARCHAR(20),
    IN p_condicion_pago VARCHAR(100),
    IN p_plazo_entrega VARCHAR(100),
    IN p_descuento_comercial DECIMAL(5,2),
    IN p_es_agente_retencion TINYINT(1),
    IN p_es_buen_contribuyente TINYINT(1),
    IN p_tiene_certificado_calidad TINYINT(1),
    IN p_certificados_adjuntos TEXT,
    IN p_estado VARCHAR(20),
    IN p_motivo_inactivo TEXT,
    IN p_observaciones TEXT,
    IN p_notas_internas TEXT,
    IN p_actualizado_por VARCHAR(20)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc_actual) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Proveedor no encontrado';
    END IF;

    -- El RUC es la llave primaria: si cambia, no debe existir otro registro con ese valor
    IF IFNULL(p_ruc_nuevo, p_ruc_actual) <> p_ruc_actual
       AND EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc_nuevo) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'El RUC ya está registrado';
    END IF;

    -- IFNULL conserva el valor actual cuando la API no envía el campo,
    -- así la edición básica del formulario no borra datos de otros módulos.
    UPDATE TblProveedores SET
        ruc                   = IFNULL(p_ruc_nuevo, ruc),
        razon_social          = IFNULL(p_razon_social, razon_social),
        nombre_comercial      = IFNULL(p_nombre_comercial, nombre_comercial),
        tipo_contribuyente    = IFNULL(p_tipo_contribuyente, tipo_contribuyente),
        telefono              = IFNULL(p_telefono, telefono),
        telefono_alternativo  = IFNULL(p_telefono_alternativo, telefono_alternativo),
        email                 = IFNULL(p_email, email),
        email_facturacion     = IFNULL(p_email_facturacion, email_facturacion),
        sitio_web             = IFNULL(p_sitio_web, sitio_web),
        direccion_fiscal      = IFNULL(p_direccion_fiscal, direccion_fiscal),
        departamento          = IFNULL(p_departamento, departamento),
        provincia             = IFNULL(p_provincia, provincia),
        distrito              = IFNULL(p_distrito, distrito),
        ubigeo                = IFNULL(p_ubigeo, ubigeo),
        referencia            = IFNULL(p_referencia, referencia),
        contacto_nombre       = IFNULL(p_contacto_nombre, contacto_nombre),
        contacto_cargo        = IFNULL(p_contacto_cargo, contacto_cargo),
        contacto_telefono     = IFNULL(p_contacto_telefono, contacto_telefono),
        contacto_email        = IFNULL(p_contacto_email, contacto_email),
        contacto_dni          = IFNULL(p_contacto_dni, contacto_dni),
        banco_1               = IFNULL(p_banco_1, banco_1),
        cuenta_banco_1        = IFNULL(p_cuenta_banco_1, cuenta_banco_1),
        tipo_cuenta_1         = IFNULL(p_tipo_cuenta_1, tipo_cuenta_1),
        moneda_1              = IFNULL(p_moneda_1, moneda_1),
        cci_1                 = IFNULL(p_cci_1, cci_1),
        banco_2               = IFNULL(p_banco_2, banco_2),
        cuenta_banco_2        = IFNULL(p_cuenta_banco_2, cuenta_banco_2),
        tipo_cuenta_2         = IFNULL(p_tipo_cuenta_2, tipo_cuenta_2),
        moneda_2              = IFNULL(p_moneda_2, moneda_2),
        cci_2                 = IFNULL(p_cci_2, cci_2),
        rubro_negocio         = IFNULL(p_rubro_negocio, rubro_negocio),
        categoria             = IFNULL(p_categoria, categoria),
        calificacion          = IFNULL(p_calificacion, calificacion),
        condicion_pago        = IFNULL(p_condicion_pago, condicion_pago),
        plazo_entrega         = IFNULL(p_plazo_entrega, plazo_entrega),
        descuento_comercial   = IFNULL(p_descuento_comercial, descuento_comercial),
        es_agente_retencion   = IFNULL(p_es_agente_retencion, es_agente_retencion),
        es_buen_contribuyente = IFNULL(p_es_buen_contribuyente, es_buen_contribuyente),
        tiene_certificado_calidad = IFNULL(p_tiene_certificado_calidad, tiene_certificado_calidad),
        certificados_adjuntos = IFNULL(p_certificados_adjuntos, certificados_adjuntos),
        estado                = IFNULL(p_estado, estado),
        motivo_inactivo       = IFNULL(p_motivo_inactivo, motivo_inactivo),
        observaciones         = IFNULL(p_observaciones, observaciones),
        notas_internas        = IFNULL(p_notas_internas, notas_internas),
        actualizado_por       = p_actualizado_por,
        fecha_actualizacion   = NOW()
    WHERE ruc = p_ruc_actual;

    SELECT IFNULL(p_ruc_nuevo, p_ruc_actual) AS ruc, 1 AS resultado, 'Proveedor actualizado' AS mensaje;
END

-- @SP sp_EliminarProveedor
DROP PROCEDURE IF EXISTS sp_EliminarProveedor;
CREATE PROCEDURE sp_EliminarProveedor(
    IN p_ruc VARCHAR(11),
    IN p_usuario VARCHAR(20)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM TblProveedores WHERE ruc = p_ruc AND estado != 'ELIMINADO') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Proveedor no encontrado o ya eliminado';
    END IF;

    -- Baja lógica: el registro se conserva con estado ELIMINADO
    -- (sp_ListarProveedores y sp_ObtenerProveedorPorRUC lo excluyen).
    UPDATE TblProveedores
    SET estado = 'ELIMINADO',
        actualizado_por = p_usuario,
        fecha_actualizacion = NOW()
    WHERE ruc = p_ruc;

    SELECT p_ruc AS ruc, 1 AS resultado, 'Proveedor eliminado' AS mensaje;
END

-- ============================================================================
-- DEPENDENCIA DE BD (ya aplicada): TblMateriales.id_proveedor -> TblProveedores.ruc
-- Se exige ON UPDATE CASCADE para que, al editar el RUC de un proveedor
-- (sp_ActualizarProveedor), los materiales vinculados se actualicen solos.
-- ALTER TABLE TblMateriales DROP FOREIGN KEY fk_materiales_proveedores;
-- ALTER TABLE TblMateriales ADD CONSTRAINT fk_materiales_proveedores
--     FOREIGN KEY (id_proveedor) REFERENCES TblProveedores (ruc)
--     ON UPDATE CASCADE ON DELETE NO ACTION;
-- ============================================================================
