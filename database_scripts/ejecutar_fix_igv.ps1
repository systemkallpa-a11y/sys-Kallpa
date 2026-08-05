# ═══════════════════════════════════════════════════════════════════════════
# Script PowerShell para ejecutar fix_igv_calculation_v2.sql
# ═══════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  CORRECCIÓN DEL CÁLCULO DEL IGV EN STORED PROCEDURES" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Configuración
$scriptPath = "$PSScriptRoot\fix_igv_calculation_v2.sql"
$mysqlPath = "mysql"  # Asume que mysql está en el PATH
$database = "Kallpa"

# Verificar que el script SQL existe
if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ ERROR: No se encontró el archivo fix_igv_calculation_v2.sql" -ForegroundColor Red
    Write-Host "   Ruta esperada: $scriptPath" -ForegroundColor Gray
    exit 1
}

Write-Host "📁 Script SQL encontrado: fix_igv_calculation_v2.sql" -ForegroundColor Green
Write-Host ""

# Solicitar credenciales
Write-Host "Ingrese las credenciales de MySQL:" -ForegroundColor White
$username = Read-Host "Usuario (por defecto: kallpasystem)"
if ([string]::IsNullOrWhiteSpace($username)) {
    $username = "kallpasystem"
}

$password = Read-Host "Contraseña" -AsSecureString
$passwordPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

Write-Host ""
Write-Host "🔄 Ejecutando script SQL..." -ForegroundColor Yellow
Write-Host ""

# Ejecutar el script SQL
try {
    # Crear comando
    $mysqlCmd = "& `"$mysqlPath`" -u $username -p$passwordPlain $database"
    
    # Ejecutar
    Get-Content $scriptPath | & $mysqlPath -u $username "-p$passwordPlain" $database 2>&1 | ForEach-Object {
        if ($_ -match "ERROR") {
            Write-Host "❌ $_" -ForegroundColor Red
        } elseif ($_ -match "warning") {
            Write-Host "⚠️  $_" -ForegroundColor Yellow
        } else {
            Write-Host "$_" -ForegroundColor Gray
        }
    }
    
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  ✅ SCRIPT EJECUTADO CORRECTAMENTE" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "PRÓXIMOS PASOS:" -ForegroundColor Yellow
    Write-Host "  1. Verificar stored procedures actualizados" -ForegroundColor White
    Write-Host "  2. Reiniciar servidor Python: python main.py" -ForegroundColor White
    Write-Host "  3. Probar crear/editar un presupuesto" -ForegroundColor White
    Write-Host "  4. Verificar que el IGV se guarde correctamente en BD" -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host ""
    Write-Host "❌ ERROR AL EJECUTAR EL SCRIPT:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    Write-Host "SOLUCIÓN ALTERNATIVA:" -ForegroundColor Yellow
    Write-Host "  Ejecutar manualmente desde MySQL Workbench o línea de comandos:" -ForegroundColor White
    Write-Host "  mysql -u $username -p $database < fix_igv_calculation_v2.sql" -ForegroundColor Gray
    Write-Host ""
    exit 1
}

# Pausa al final
Write-Host "Presione cualquier tecla para continuar..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
