$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$app = Join-Path $root "app\duo_desktop.exe"
$service = Join-Path $root "service\DuoDesktop.Service.exe"

if (-not (Test-Path $app)) {
  Write-Host "No se encontro la aplicacion: $app" -ForegroundColor Red
  Read-Host "Presiona Enter para cerrar"
  exit 1
}

if (-not (Test-Path $service)) {
  Write-Host "No se encontro el servicio local: $service" -ForegroundColor Red
  Read-Host "Presiona Enter para cerrar"
  exit 1
}

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ($listener.LocalEndpoint).Port
$listener.Stop()

$token = [guid]::NewGuid().ToString("N") + [guid]::NewGuid().ToString("N")
$env:DUO_SERVICE_PORT = "$port"
$env:DUO_TOKEN = $token
$serviceLog = Join-Path $root "duo-service.log"

Write-Host "Iniciando Duo Desktop..." -ForegroundColor Cyan

$serviceArgs = @("--urls", "http://127.0.0.1:$port")
$serviceProcess = Start-Process -FilePath $service -ArgumentList $serviceArgs -WorkingDirectory (Split-Path -Parent $service) -WindowStyle Hidden -RedirectStandardOutput $serviceLog -RedirectStandardError "$serviceLog.err" -PassThru

try {
  $deadline = [DateTime]::UtcNow.AddSeconds(12)
  $ready = $false
  while ([DateTime]::UtcNow -lt $deadline) {
    try {
      $response = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -TimeoutSec 1
      if ($response.StatusCode -eq 200) {
        $ready = $true
        break
      }
    } catch {
      Start-Sleep -Milliseconds 250
    }
  }

  if (-not $ready) {
    throw "El servicio local no respondio a tiempo."
  }

  $appProcess = Start-Process -FilePath $app -WorkingDirectory (Split-Path -Parent $app) -PassThru
  $appProcess.WaitForExit()
  if ($appProcess.ExitCode -ne 0) {
    throw "La aplicacion termino con codigo $($appProcess.ExitCode). Revisa duo-service.log en esta carpeta."
  }
}
catch {
  Write-Host ""
  Write-Host "No se pudo iniciar Duo Desktop:" -ForegroundColor Red
  Write-Host $_.Exception.Message -ForegroundColor Red
  Read-Host "Presiona Enter para cerrar"
}
finally {
  if ($serviceProcess -and -not $serviceProcess.HasExited) {
    Stop-Process -Id $serviceProcess.Id -Force -ErrorAction SilentlyContinue
  }
}
