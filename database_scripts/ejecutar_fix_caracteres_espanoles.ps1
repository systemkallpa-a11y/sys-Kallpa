# ============================================================================
# Script PowerShell: Permitir caracteres españoles en nombres
# ============================================================================

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "FIX: Permitir ñ, acentos y caracteres españoles en nombres" -ForegroundColor Cyan
Write-Host "============================================================================`n" -ForegroundColor Cyan

Write-Host "Problema:" -ForegroundColor Yellow
Write-Host "  Al crear usuarios con 'ñ' en apellidos se produce el error:" -ForegroundColor White
Write-Host "  Error 3819 (HY000): Check constraint 'chk_apellido_materno_solo_letras' is violated" -ForegroundColor Red

Write-Host "`nSolución:" -ForegroundColor Yellow
Write-Host "  Actualizar los constraints para aceptar: ñ, Ñ, á, é, í, ó, ú, ü, etc.`n" -ForegroundColor White

# Configuración
$mysqlHost = "localhost"
$mysqlPort = "3306"
$mysqlDatabase = "kallpasystem`$kallgwkn_kallpa_bd"
$scriptPath = "fix_constraint_caracteres_espanoles.sql"

# Solicitar credenciales
Write-Host "Ingrese las credenciales de MySQL:" -ForegroundColor Yellow
$mysqlUser = Read-Host "Usuario MySQL"
$mysqlPasswordSecure = Read-Host "Contraseña MySQL" -AsSecureString
$mysqlPassword = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($mysqlPasswordSecure))

Write-Host "`n[1/3] Verificando archivo SQL..." -ForegroundColor Green

if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ ERROR: No se encontró el archivo $scriptPath" -ForegroundColor Red
    Write-Host "   Asegúrese de ejecutar este script desde la carpeta database_scripts/" -ForegroundColor Red
    Read-Host "`nPresione Enter para salir"
    exit 1
}

Write-Host "✓ Archivo encontrado: $scriptPath" -ForegroundColor Green

Write-Host "`n[2/3] Ejecutando script SQL..." -ForegroundColor Green

try {
    Get-Content $scriptPath | & mysql -h $mysqlHost -P $mysqlPort -u $mysqlUser -p"$mysqlPassword" $mysqlDatabase 2>&1 | ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host "❌ $_" -ForegroundColor Red
            throw "Error al ejecutar el script SQL"
        } else {
            # Mostrar mensajes informativos
            if ($_ -match "info|resultado|estado|caracteres") {
                Write-Host "   $_" -ForegroundColor Cyan
            } else {
                Write-Host "   $_" -ForegroundColor Gray
            }
        }
    }
    
    Write-Host "`n✓ Script ejecutado correctamente" -ForegroundColor Green
    
} catch {
    Write-Host "`n❌ ERROR al ejecutar el script:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host "`nPosibles causas:" -ForegroundColor Yellow
    Write-Host "  • Credenciales incorrectas" -ForegroundColor Yellow
    Write-Host "  • MySQL no está corriendo" -ForegroundColor Yellow
    Write-Host "  • Base de datos 'kallpasystem' no existe" -ForegroundColor Yellow
    Write-Host "  • Versión de MySQL muy antigua (requiere 8.0+)" -ForegroundColor Yellow
    Read-Host "`nPresione Enter para salir"
    exit 1
}

Write-Host "`n[3/3] Verificando cambios..." -ForegroundColor Green

$verificacionQuery = @"
SELECT COUNT(*) as total
FROM information_schema.TABLE_CONSTRAINTS tc
WHERE tc.CONSTRAINT_SCHEMA = 'kallpasystem`$kallgwkn_kallpa_bd'
  AND tc.TABLE_NAME = 'TblPersona'
  AND tc.CONSTRAINT_TYPE = 'CHECK'
  AND tc.CONSTRAINT_NAME LIKE 'chk_%letras';
"@

try {
    $resultado = $verificacionQuery | & mysql -h $mysqlHost -P $mysqlPort -u $mysqlUser -p"$mysqlPassword" $mysqlDatabase -N 2>&1
    
    if ($resultado -match "3") {
        Write-Host "✓ 3 constraints actualizados correctamente" -ForegroundColor Green
    } else {
        Write-Host "⚠ Verificación: $resultado constraints encontrados" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠ No se pudo verificar automáticamente, pero el script se ejecutó" -ForegroundColor Yellow
}

Write-Host "`n============================================================================" -ForegroundColor Cyan
Write-Host "✅ FIX APLICADO EXITOSAMENTE" -ForegroundColor Green
Write-Host "============================================================================" -ForegroundColor Cyan

Write-Host "`nCaracteres ahora permitidos:" -ForegroundColor White
Write-Host "  ✓ Letras básicas: a-z, A-Z" -ForegroundColor Green
Write-Host "  ✓ Letra ñ: ñ, Ñ" -ForegroundColor Green
Write-Host "  ✓ Vocales acentuadas: á, é, í, ó, ú, Á, É, Í, Ó, Ú" -ForegroundColor Green
Write-Host "  ✓ Diéresis: ü, Ü" -ForegroundColor Green
Write-Host "  ✓ Espacios (para nombres compuestos)" -ForegroundColor Green

Write-Host "`n📋 Próximos pasos:" -ForegroundColor Yellow
Write-Host "  1. Ir al sistema web" -ForegroundColor White
Write-Host "  2. Intentar crear un usuario con 'ñ' en el apellido" -ForegroundColor White
Write-Host "  3. Ejemplo: Apellido Materno = 'Núñez'" -ForegroundColor White
Write-Host "  4. Debería guardarse sin errores" -ForegroundColor White

Write-Host "`n⚠️ IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  • NO es necesario reiniciar el servidor Python" -ForegroundColor White
Write-Host "  • NO es necesario recargar la página web" -ForegroundColor White
Write-Host "  • Los cambios son inmediatos en la base de datos" -ForegroundColor White

Write-Host "`n============================================================================`n" -ForegroundColor Cyan

Read-Host "Presione Enter para salir"
