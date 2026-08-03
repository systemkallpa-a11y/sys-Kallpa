-- ============================================================================
-- HABILITAR CREACIÓN DE TRIGGERS SIN PRIVILEGIO SUPER
-- ============================================================================

-- Verificar el valor actual
SHOW VARIABLES LIKE 'log_bin_trust_function_creators';

-- Habilitar
SET GLOBAL log_bin_trust_function_creators = 1;

-- Verificar que se cambió
SHOW VARIABLES LIKE 'log_bin_trust_function_creators';

SELECT '✅ Ahora puedes crear los triggers' as mensaje;
