# ============================================================================
# Script PowerShell para ejecutar sp_ExportarMarcacionDetallada.sql
# ============================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  KALLPA - Creación SP Exportar Marcación Detallada" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Solicitar credenciales de MySQL
$host_mysql = Read-Host "Host MySQL (default: localhost)"
if ([string]::IsNullOrWhiteSpace($host_mysql)) { $host_mysql = "localhost" }

$usuario = Read-Host "Usuario MySQL (default: root)"
if ([string]::IsNullOrWhiteSpace($usuario)) { $usuario = "root" }

$password = Read-Host "Contraseña MySQL" -AsSecureString
$password_plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
)

$database = Read-Host "Base de datos (default: Kallpa)"
if ([string]::IsNullOrWhiteSpace($database)) { $database = "Kallpa" }

Write-Host ""
Write-Host "Conectando a MySQL..." -ForegroundColor Yellow

# Ejecutar el script SQL
try {
    $output = & mysql -h $host_mysql -u $usuario -p"$password_plain" $database -e "source sp_ExportarMarcacionDetallada.sql" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✅ Stored Procedure creado exitosamente" -ForegroundColor Green
        Write-Host ""
        Write-Host "SP disponible: sp_ExportarMarcacionDetallada" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "❌ Error al ejecutar el script:" -ForegroundColor Red
        Write-Host $output -ForegroundColor Red
        Write-Host ""
    }
} catch {
    Write-Host ""
    Write-Host "❌ Error al conectar con MySQL:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}

Write-Host "Presiona cualquier tecla para continuar..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
