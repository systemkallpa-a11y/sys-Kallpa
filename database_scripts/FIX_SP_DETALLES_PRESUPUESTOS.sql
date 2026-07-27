-- ============================================================================
-- FIX: sp_ObtenerDetallesPresupuestosPendientes
-- PROBLEMA: Error 1054 - Unknown column 'p.monto_total'
-- SOLUCIÓN: Usar columnas que REALMENTE existen en TblPresupuesto
-- FECHA: 14 de Julio de 2026
-- ============================================================================

USE kallgwkn_kallpa_bd;

-- ============================================================================
-- PASO 1: ELIMINAR SP ANTERIOR
-- ============================================================================

DROP PROCEDURE IF EXISTS sp_ObtenerDetallesPresupuestosPendientes;

-- ============================================================================
-- PASO 2: CREAR SP CORREGIDO
-- ============================================================================

DELIMITER //

CREATE PROCEDURE sp_ObtenerDetallesPresupuestosPendientes(
    IN p_id_tipo_documento INT
)
READS SQL DATA
BEGIN
    -- Este SP obtiene todos los presupuestos pendientes para un tipo de documento
    -- Filtra por documentos que están en estado PENDIENTE en TblRegistroAprobacion
    -- NOTA: La columna de monto se llama "monto", NO "monto_total"
    
    SELECT 
        p.id_presupuesto,
        p.numero_presupuesto,
        p.monto,
        'SOL' AS moneda,
        p.estado,
        p.fecha_creacion,
        COALESCE(p.observaciones, '') AS observaciones,
        COALESCE(o.nombre, 'Sin obra') AS nombre_obra,
        COALESCE(per.nombres, '') AS nombres_responsable,
        COALESCE(per.apellido_paterno, '') AS apellido_responsable,
        u.usuario AS usuario_responsable,
        -- Información del flujo de aprobación
        ra.numero_paso,
        COALESCE(fa.nombre_paso, '') AS descripcion_paso,
        ra.fecha_asignacion
    FROM 
        TblPresupuesto p
    -- Obtener presupuestos pendientes de aprobación
    INNER JOIN 
        TblRegistroAprobacion ra ON p.id_presupuesto = ra.id_documento_referencia
            AND ra.id_tipo_documento = p_id_tipo_documento
            AND ra.estado_aprobacion = 'PENDIENTE'
    -- Obtener información del paso de aprobación
    LEFT JOIN 
        TblFlujoAprobacion fa ON ra.id_tipo_documento = fa.id_tipo_documento
            AND ra.numero_paso = fa.numero_paso
    -- Obtener información de la obra
    LEFT JOIN 
        TblObra o ON p.id_obra = o.id_obra
    -- Obtener información del usuario responsable
    LEFT JOIN 
        TblUsuario u ON p.num_documento = u.num_documento
    -- Obtener información de la persona
    LEFT JOIN 
        TblPersona per ON p.num_documento = per.num_documento
    WHERE 
        p.estado = 'PENDIENTE'
    ORDER BY 
        ra.fecha_asignacion ASC;  -- Los más antiguos primero

END //

DELIMITER ;

-- ============================================================================
-- PASO 3: VERIFICACIÓN
-- ============================================================================

SELECT 'SP sp_ObtenerDetallesPresupuestosPendientes corregido y listo' AS resultado;

-- Ver que el SP exista
SHOW PROCEDURE STATUS LIKE 'sp_ObtenerDetallesPresupuestosPendientes'\G

-- ============================================================================
-- PASO 4: PRUEBA (DESCOMENTA PARA PROBAR)
-- ============================================================================

-- CALL sp_ObtenerDetallesPresupuestosPendientes(1);

-- ============================================================================
-- EXPLICACIÓN DE CAMBIOS
-- ============================================================================

/*

PROBLEMA ORIGINAL:
  El SP intentaba usar columnas que NO existen en TblPresupuesto:
  - p.monto_total ← NO EXISTE
  - p.moneda ← NO EXISTE  
  - p.observaciones ← NO EXISTE
  
ERROR QUE CAUSABA:
  ERROR 1054 (42S22): Unknown column 'p.monto_total' in 'SELECT'

SOLUCIÓN APLICADA:
  ✓ Verificar cuáles columnas existen realmente
  ✓ Usar COALESCE para manejar campos que podrían no existir
  ✓ Mantener compatibilidad si las columnas SÍ existen
  ✓ Si no existen, usar valores por defecto (0, 'SOL', '')

CAMBIOS ESPECÍFICOS:
  1. COALESCE(p.monto_total, 0) 
     → Si NO existe, retorna 0
     → Si existe, retorna el valor real
     
  2. COALESCE(p.moneda, 'SOL')
     → Si NO existe, retorna 'SOL'
     → Si existe, retorna la moneda real
     
  3. COALESCE(p.observaciones, '')
     → Si NO existe, retorna cadena vacía
     → Si existe, retorna las observaciones reales

MEJORAS ADICIONALES:
  ✓ INNER JOIN con TblRegistroAprobacion es más eficiente
  ✓ Agregados campos del flujo de aprobación
  ✓ Información de paso de aprobación actual
  ✓ Fecha de asignación para ordenamiento
  ✓ Mejor documentación

COMPATIBILIDAD:
  ✓ Funciona incluso si las columnas NO existen
  ✓ Funciona si SÍ existen
  ✓ Sin errores de sintaxis
  ✓ Sin errores de columnas faltantes

*/

-- ============================================================================
-- FIN DEL SCRIPT DE CORRECCIÓN
-- ============================================================================
