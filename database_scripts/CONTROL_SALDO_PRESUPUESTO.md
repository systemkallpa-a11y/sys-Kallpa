# CONTROL DE SALDO EN PRESUPUESTOS

## 📊 PROBLEMA

Un presupuesto tiene 150 unidades (materiales + servicios).
Se pueden crear múltiples requerimientos de ese presupuesto:
- Req 1: 50 und
- Req 2: 20 und  
- Req 3: 50 und
- **Saldo: 30 und** (no se puede superar 150)

Necesitamos:
1. Rastrear cuánto se ha consumido del presupuesto
2. Validar antes de crear cada requerimiento
3. Permitir saldos parciales

---

## 🗂️ ESTRUCTURA DE TABLAS

### 1. TblPresupuesto (MODIFICACIONES)

```sql
ALTER TABLE TblPresupuesto ADD COLUMN IF NOT EXISTS cantidad_original INT COMMENT 'Cantidad total presupuestada';
ALTER TABLE TblPresupuesto ADD COLUMN IF NOT EXISTS cantidad_consumida INT DEFAULT 0 COMMENT 'Cantidad usada en requerimientos';
ALTER TABLE TblPresupuesto ADD COLUMN IF NOT EXISTS cantidad_saldo INT GENERATED ALWAYS AS (cantidad_original - cantidad_consumida) STORED COMMENT 'Saldo disponible (calculado)';
```

**Campos importantes:**
- `id_presupuesto` (PK)
- `cantidad_original` ← Total presupuestado
- `cantidad_consumida` ← Suma de requerimientos
- `cantidad_saldo` ← Calculada automáticamente (original - consumida)

---

### 2. TblPresupuestoDetalle (VERIFICAR)

Ya existe, tiene:
- `id_detalle` (PK)
- `id_presupuesto` (FK)
- `cantidad` (cantidad del item individual)
- `tipo_item` (MATERIAL o SERVICIO)

---

### 3. TblRequerimiento (VERIFICAR)

Ya existe, tiene:
- `id_requerimiento` (PK)
- `id_presupuesto` (FK) ← Vinculado al presupuesto original
- `cantidad` (total de items en este requerimiento)
- `estado` (PENDIENTE, APROBADO, etc.)

---

### 4. TblRequerimientoAuditoria (NUEVA)

**Propósito:** Rastrear cada cambio en los saldos

```sql
CREATE TABLE IF NOT EXISTS TblRequerimientoAuditoria (
    id_auditoria INT AUTO_INCREMENT PRIMARY KEY,
    id_presupuesto INT NOT NULL,
    id_requerimiento INT NOT NULL,
    cantidad_requerida INT,
    cantidad_anterior_consumida INT,
    cantidad_nueva_consumida INT,
    saldo_anterior INT,
    saldo_nuevo INT,
    accion VARCHAR(20), -- 'CREAR', 'ACTUALIZAR', 'CANCELAR'
    usuario INT,
    fecha_registro DATETIME DEFAULT NOW(),
    
    FOREIGN KEY (id_presupuesto) REFERENCES TblPresupuesto(id_presupuesto),
    FOREIGN KEY (id_requerimiento) REFERENCES TblRequerimiento(id_requerimiento),
    INDEX idx_presupuesto (id_presupuesto),
    INDEX idx_requerimiento (id_requerimiento)
);
```

---

## 🔍 FLUJO DE VALIDACIÓN

### Paso 1: Verificar saldo disponible

```sql
-- Antes de crear requerimiento
SELECT 
    id_presupuesto,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo,
    CASE 
        WHEN cantidad_saldo >= ? THEN 'PERMITIDO'
        ELSE 'RECHAZADO - Saldo insuficiente'
    END as estado
FROM TblPresupuesto
WHERE id_presupuesto = ?;
```

### Paso 2: Crear requerimiento

```sql
-- Si hay saldo, crear requerimiento
INSERT INTO TblRequerimiento (...)
VALUES (...);

-- Actualizar consumo en presupuesto
UPDATE TblPresupuesto
SET cantidad_consumida = cantidad_consumida + ?
WHERE id_presupuesto = ?;

-- Registrar en auditoría
INSERT INTO TblRequerimientoAuditoria (...)
VALUES (...);
```

### Paso 3: Consultar saldo

```sql
SELECT 
    cantidad_saldo as saldo_disponible
FROM TblPresupuesto
WHERE id_presupuesto = ?;
```

---

## 💾 SP VALIDAR SALDO

```sql
CREATE PROCEDURE sp_ValidarSaldoPresupuesto(
    IN p_id_presupuesto INT,
    IN p_cantidad_requerida INT,
    OUT p_saldo_disponible INT,
    OUT p_permitido BOOLEAN
)
BEGIN
    SELECT cantidad_saldo
    INTO p_saldo_disponible
    FROM TblPresupuesto
    WHERE id_presupuesto = p_id_presupuesto;
    
    IF p_saldo_disponible >= p_cantidad_requerida THEN
        SET p_permitido = TRUE;
    ELSE
        SET p_permitido = FALSE;
    END IF;
END;
```

---

## 📋 EJEMPLO DE EJECUCIÓN

```sql
-- Presupuesto con 150 und
INSERT INTO TblPresupuesto (cantidad_original) VALUES (150);
-- cantidad_consumida = 0
-- cantidad_saldo = 150

-- Crear Req 1: 50 und
CALL sp_CrearRequerimientoCompleto(1, 'Req 1', '', [...], @id1);
-- UPDATE TblPresupuesto SET cantidad_consumida = 50
-- cantidad_saldo = 100

-- Crear Req 2: 20 und
CALL sp_CrearRequerimientoCompleto(1, 'Req 2', '', [...], @id2);
-- UPDATE TblPresupuesto SET cantidad_consumida = 70
-- cantidad_saldo = 80

-- Crear Req 3: 50 und
CALL sp_CrearRequerimientoCompleto(1, 'Req 3', '', [...], @id3);
-- UPDATE TblPresupuesto SET cantidad_consumida = 120
-- cantidad_saldo = 30

-- Intentar Req 4: 50 und (RECHAZADO - solo quedan 30)
CALL sp_CrearRequerimientoCompleto(1, 'Req 4', '', [...], @id4);
-- ERROR: Saldo insuficiente
```

---

## 🎯 CAMBIOS EN EL SP

El SP `sp_CrearRequerimientoCompleto` necesita:

1. **Validar saldo ANTES de crear**
2. **Actualizar cantidad_consumida DESPUÉS de crear**
3. **Registrar en auditoría**

```sql
-- DENTRO DEL SP
-- 1. Verificar saldo
SELECT cantidad_saldo INTO v_saldo
FROM TblPresupuesto
WHERE id_presupuesto = v_id_presupuesto;

IF v_saldo < v_cantidad_total THEN
    SIGNAL SQLSTATE '45000' 
    SET MESSAGE_TEXT = 'Saldo insuficiente en presupuesto';
END IF;

-- 2. Crear requerimiento (código existente)
INSERT INTO TblRequerimiento (...) VALUES (...);

-- 3. Actualizar consumo
UPDATE TblPresupuesto
SET cantidad_consumida = cantidad_consumida + v_cantidad_total
WHERE id_presupuesto = v_id_presupuesto;

-- 4. Registrar auditoría
INSERT INTO TblRequerimientoAuditoria (...)
VALUES (...);
```

---

## 📊 CONSULTAS ÚTILES

### Ver saldo de un presupuesto
```sql
SELECT 
    id_presupuesto,
    cantidad_original,
    cantidad_consumida,
    cantidad_saldo
FROM TblPresupuesto
WHERE id_presupuesto = 1;
```

### Ver requerimientos de un presupuesto
```sql
SELECT 
    r.id_requerimiento,
    r.codigo,
    r.cantidad,
    r.estado,
    p.cantidad_saldo
FROM TblRequerimiento r
JOIN TblPresupuesto p ON r.id_presupuesto = p.id_presupuesto
WHERE r.id_presupuesto = 1
ORDER BY r.fecha_creacion;
```

### Ver auditoría de cambios
```sql
SELECT 
    fecha_registro,
    accion,
    cantidad_requerida,
    saldo_anterior,
    saldo_nuevo
FROM TblRequerimientoAuditoria
WHERE id_presupuesto = 1
ORDER BY fecha_registro DESC;
```

---

## ✅ PRÓXIMOS PASOS

1. ✓ Agregar columnas a TblPresupuesto
2. ✓ Crear tabla TblRequerimientoAuditoria
3. ✓ Actualizar SP sp_CrearRequerimientoCompleto con validación
4. ✓ Actualizar SP sp_ActualizarRequerimiento para ajustar saldos
5. ✓ Crear SP para cancelar requerimientos (devolver saldo)
6. ✓ Agregar endpoint en backend para ver saldo disponible
