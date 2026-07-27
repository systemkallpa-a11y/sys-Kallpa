-- ============================================================================
-- Script: Diagnóstico Completo del Presupuesto 1
-- Propósito: Investigar por qué el SP no retorna datos
-- Fecha: 10 Julio 2026
-- ============================================================================

SELECT '═══════════════════════════════════════════════════' as separador;
SELECT 'DIAGNÓSTICO: Presupuesto ID = 1' as diagnostico;
SELECT '═══════════════════════════════════════════════════' as separador;

-- PASO 1: Verificar que el presupuesto existe
SELECT 'PASO 1: ¿Existe el presupuesto en TblPresupuesto?' as paso;
SELECT 
    id_presupuesto,
    numero_presupuesto,
    id_obra,
    num_documento,
    monto,
    estado,
    fecha_creacion
FROM TblPresupuesto 
WHERE id_presupuesto = 1;

-- PASO 2: Verificar que la obra existe
SELECT 'PASO 2: ¿Existe la obra (id_obra=1)?' as paso;
SELECT 
    id_obra,
    codigo_obra,
    nombre,
    id_proyecto
FROM TblObra 
WHERE id_obra = 1;

-- PASO 3: Verificar que el proyecto existe
SELECT 'PASO 3: ¿Existe el proyecto?' as paso;
SELECT 
    id_proyecto,
    codigo_proyecto,
    nombre
FROM TblProyecto 
WHERE id_proyecto = 1;

-- PASO 4: Verificar que el usuario existe
SELECT 'PASO 4: ¿Existe el usuario (num_documento=1)?' as paso;
SELECT 
    num_usuario,
    num_documento,
    usuario,
    estado
FROM TblUsuario 
WHERE num_documento = 1;

-- PASO 5: Verificar que la persona existe
SELECT 'PASO 5: ¿Existe la persona (num_documento=1)?' as paso;
SELECT 
    num_documento,
    nombres,
    apellido_paterno,
    email
FROM TblPersona 
WHERE num_documento = 1;

-- PASO 6: Verificar los detalles
SELECT 'PASO 6: ¿Existen detalles para id_presupuesto=1?' as paso;
SELECT 
    id_detalle,
    id_presupuesto,
    id_material,
    cantidad,
    precio_unitario,
    subtotal
FROM TblPresupuestoDetalle 
WHERE id_presupuesto = 1;

-- PASO 7: Verificar materiales
SELECT 'PASO 7: ¿Existen los materiales?' as paso;
SELECT 
    id_material,
    codigo_material,
    nombre,
    id_categoria,
    id_unidad
FROM TblMateriales 
WHERE id_material IN (1, 2, 3);

-- PASO 8: Verificar categorías
SELECT 'PASO 8: ¿Existen las categorías?' as paso;
SELECT 
    id_categoria,
    nombre
FROM TblCategoriaMaterial 
WHERE id_categoria IN (
    SELECT DISTINCT id_categoria FROM TblMateriales WHERE id_material IN (1, 2, 3)
);

-- PASO 9: Verificar unidades
SELECT 'PASO 9: ¿Existen las unidades?' as paso;
SELECT 
    id_unidad,
    codigo,
    nombre
FROM TblUnidadMedida 
WHERE id_unidad IN (
    SELECT DISTINCT id_unidad FROM TblMateriales WHERE id_material IN (1, 2, 3)
);

-- PASO 10: Probar la PARTE 1 del SP manualmente
SELECT 'PASO 10: Ejecutar PARTE 1 del SP manualmente' as paso;
SELECT 
    p.id_presupuesto,
    p.numero_presupuesto,
    p.id_obra,
    p.num_documento,
    p.monto,
    p.estado,
    COALESCE(pr.nombre, 'N/A') as nombre_proyecto,
    COALESCE(o.nombre, 'N/A') as nombre_obra,
    COALESCE(per.nombres, 'N/A') as usuario_nombres,
    COALESCE(u.usuario, 'N/A') as usuario
FROM TblPresupuesto p
LEFT JOIN TblObra o ON p.id_obra = o.id_obra
LEFT JOIN TblProyecto pr ON o.id_proyecto = pr.id_proyecto
LEFT JOIN TblUsuario u ON p.num_documento = u.num_documento
LEFT JOIN TblPersona per ON u.num_documento = per.num_documento
WHERE p.id_presupuesto = 1;

-- PASO 11: Contar registros
SELECT 'PASO 11: Conteo de registros por tabla' as paso;
SELECT 'TblPresupuesto' as tabla, COUNT(*) as total FROM TblPresupuesto
UNION ALL
SELECT 'TblPresupuestoDetalle', COUNT(*) FROM TblPresupuestoDetalle
UNION ALL
SELECT 'TblObra', COUNT(*) FROM TblObra
UNION ALL
SELECT 'TblProyecto', COUNT(*) FROM TblProyecto
UNION ALL
SELECT 'TblUsuario', COUNT(*) FROM TblUsuario
UNION ALL
SELECT 'TblPersona', COUNT(*) FROM TblPersona
UNION ALL
SELECT 'TblMateriales', COUNT(*) FROM TblMateriales;

-- PASO 12: Ejecutar el SP
SELECT 'PASO 12: Ejecutar el SP completo' as paso;
CALL sp_obtener_presupuesto_detalle_completo(1);

SELECT '═══════════════════════════════════════════════════' as separador;
SELECT 'FIN DEL DIAGNÓSTICO' as estado;
SELECT '═══════════════════════════════════════════════════' as separador;
