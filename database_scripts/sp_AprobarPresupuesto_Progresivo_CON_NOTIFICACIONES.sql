-- ============================================================================
-- STORED PROCEDURE: sp_AprobarPresupuesto_Progresivo (CON NOTIFICACIONES)
-- PROPÓSITO: Manejar aprobación en múltiples pasos + crear notificaciones
-- FECHA: 24 de Julio, 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

DROP PROCEDURE IF EXISTS sp_AprobarPresupuesto_Progresivo;

DELIMITER $$

CREATE PROCEDURE sp_AprobarPresupuesto_Progresivo(
    IN p_id_presupuesto INT,
    IN p_num_documento_aprobador INT,
    IN p_id_tipo_documento INT
)
MODIFIES SQL DATA
BEGIN
    -- DECLARAR TODAS LAS VARIABLES AL INICIO
    DECLARE v_presupuesto_existe INT DEFAULT 0;
    DECLARE v_estado_actual VARCHAR(50);
    DECLARE v_siguiente_paso INT;
    DECLARE v_pasos_totales INT DEFAULT 0;
    DECLARE v_pasos_aprobados INT DEFAULT 0;
    DECLARE v_id_cargo INT;
    DECLARE v_proximo_paso INT;
    DECLARE v_proximo_cargo INT;
    
    -- PASO 1: VALIDAR PRESUPUESTO EXISTE
    SELECT COUNT(*) INTO v_presupuesto_existe
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF v_presupuesto_existe = 0 THEN
        SELECT 'ERROR' AS resultado, 'Presupuesto no encontrado' AS mensaje;
    ELSE
        -- PASO 2: OBTENER ESTADO ACTUAL
        SELECT estado INTO v_estado_actual
        FROM TblPresupuesto
        WHERE id_presupuesto = p_id_presupuesto;
        
        IF v_estado_actual NOT IN ('PENDIENTE', 'RECHAZADO') THEN
            SELECT 'ERROR' AS resultado, 'Presupuesto no está PENDIENTE' AS mensaje;
        ELSE
            -- PASO 3: OBTENER SIGUIENTE PASO PENDIENTE
            SELECT COALESCE(MIN(fc.numero_paso), 1) INTO v_siguiente_paso
            FROM TblFlujoAprobacionCargos fc
            WHERE fc.id_tipo_documento = p_id_tipo_documento
            AND fc.numero_paso > COALESCE(
                (SELECT MAX(numero_paso)
                 FROM TblRegistroAprobacion
                 WHERE id_documento_referencia = p_id_presupuesto
                 AND estado_aprobacion = 'APROBADO'),
                0
            )
            AND fc.es_requerido = 1
            AND fc.activo = 1;
            
            -- Si no hay siguiente paso, usar el primero
            IF v_siguiente_paso IS NULL THEN
                SELECT MIN(numero_paso) INTO v_siguiente_paso
                FROM TblFlujoAprobacionCargos
                WHERE id_tipo_documento = p_id_tipo_documento
                AND es_requerido = 1
                AND activo = 1;
            END IF;
            
            IF v_siguiente_paso IS NULL THEN
                SELECT 'ERROR' AS resultado, 'No hay pasos configurados' AS mensaje;
            ELSE
                -- PASO 4: OBTENER ID CARGO DEL PASO
                SELECT id_cargo INTO v_id_cargo
                FROM TblFlujoAprobacionCargos
                WHERE id_tipo_documento = p_id_tipo_documento
                AND numero_paso = v_siguiente_paso
                AND es_requerido = 1
                AND activo = 1
                LIMIT 1;
                
                -- PASO 5: REGISTRAR APROBACIÓN DEL PASO ACTUAL
                INSERT INTO TblRegistroAprobacion (
                    id_tipo_documento,
                    id_documento_referencia,
                    numero_paso,
                    id_cargo_aprobador,
                    num_documento_aprobador,
                    estado_aprobacion,
                    fecha_aprobacion
                ) VALUES (
                    p_id_tipo_documento,
                    p_id_presupuesto,
                    v_siguiente_paso,
                    v_id_cargo,
                    p_num_documento_aprobador,
                    'APROBADO',
                    NOW()
                )
                ON DUPLICATE KEY UPDATE
                    num_documento_aprobador = p_num_documento_aprobador,
                    estado_aprobacion = 'APROBADO',
                    fecha_aprobacion = NOW();
                
                -- PASO 6: CONTAR PASOS TOTALES Y APROBADOS
                SELECT COUNT(DISTINCT numero_paso) INTO v_pasos_totales
                FROM TblFlujoAprobacionCargos
                WHERE id_tipo_documento = p_id_tipo_documento
                AND es_requerido = 1
                AND activo = 1;
                
                SELECT COUNT(*) INTO v_pasos_aprobados
                FROM TblRegistroAprobacion
                WHERE id_documento_referencia = p_id_presupuesto
                AND id_tipo_documento = p_id_tipo_documento
                AND estado_aprobacion = 'APROBADO';
                
                -- PASO 7: SI TODOS APROBADOS, CAMBIAR ESTADO
                IF v_pasos_totales = v_pasos_aprobados AND v_pasos_totales > 0 THEN
                    UPDATE TblPresupuesto
                    SET estado = 'APROBADO', fecha_actualizacion = NOW()
                    WHERE id_presupuesto = p_id_presupuesto;
                    
                    SELECT 'OK' AS resultado, 'PRESUPUESTO APROBADO' AS mensaje, v_siguiente_paso AS paso;
                ELSE
                    -- PASO 8: CREAR REGISTRO PENDIENTE PARA SIGUIENTE PASO
                    -- Así el siguiente aprobador (Gerente General) verá la notificación automáticamente
                    SELECT MIN(numero_paso) INTO v_proximo_paso
                    FROM TblFlujoAprobacionCargos
                    WHERE id_tipo_documento = p_id_tipo_documento
                    AND numero_paso > v_siguiente_paso
                    AND es_requerido = 1
                    AND activo = 1;
                    
                    IF v_proximo_paso IS NOT NULL THEN
                        -- Obtener el cargo del siguiente paso
                        SELECT id_cargo INTO v_proximo_cargo
                        FROM TblFlujoAprobacionCargos
                        WHERE id_tipo_documento = p_id_tipo_documento
                        AND numero_paso = v_proximo_paso
                        AND es_requerido = 1
                        AND activo = 1
                        LIMIT 1;
                        
                        -- Crear registro PENDIENTE para el siguiente paso
                        -- Esto hace que aparezca en las notificaciones del siguiente aprobador
                        INSERT INTO TblRegistroAprobacion (
                            id_tipo_documento,
                            id_documento_referencia,
                            numero_paso,
                            id_cargo_aprobador,
                            estado_aprobacion,
                            fecha_asignacion
                        ) VALUES (
                            p_id_tipo_documento,
                            p_id_presupuesto,
                            v_proximo_paso,
                            v_proximo_cargo,
                            'PENDIENTE',
                            NOW()
                        )
                        ON DUPLICATE KEY UPDATE
                            estado_aprobacion = 'PENDIENTE',
                            fecha_asignacion = NOW();
                    END IF;
                    
                    SELECT 'OK' AS resultado, 'Paso aprobado - Notificación enviada al siguiente aprobador' AS mensaje, v_siguiente_paso AS paso;
                END IF;
            END IF;
        END IF;
    END IF;

END$$

DELIMITER ;

-- VERIFICACIÓN
SELECT 'SP sp_AprobarPresupuesto_Progresivo creado exitosamente CON NOTIFICACIONES' as estado;
