# flm-setup.ps1 — FreeLLMAPI local no Windows (porta 3002) + admin
# Cria o codigo (clone + build), sobe o gateway em segundo plano e o admin.
# Uso:  dsh flm-setup   (ou: powershell -File tools\flm-setup.ps1)
$ErrorActionPreference = "Stop"
$proj = Join-Path $env:USERPROFILE "projects\freellmapi"
$db   = Join-Path $env:USERPROFILE ".dsh\freeapi.db"
$log  = Join-Path $env:USERPROFILE ".dsh\flm.log"

Write-Host "== FreeLLMAPI (Windows) =="
if (-not (Test-Path (Join-Path $proj ".git"))) {
  Write-Host "Clonando codigo do FreeLLMAPI..."
  New-Item -ItemType Directory -Force -Path (Split-Path $proj -Parent) | Out-Null
  git clone https://github.com/tashfeenahmed/freellmapi.git $proj
}
$needBuild = (-not (Test-Path (Join-Path $proj "server\dist\index.js"))) -or
             (-not (Test-Path (Join-Path $proj "client\dist\index.html")))
if ($needBuild) {
  Write-Host "Instalando dependencias e compilando (pode levar alguns minutos)..."
  Set-Location $proj
  npm install
  npm run build
}
Write-Host "Preparando banco e admin..."
$env:FLM_SERVER = Join-Path $proj "server"
$env:FLM_DB = $db
$env:FLM_PW = "Freellmapi@2026"
node (Join-Path (Split-Path $PSScriptRoot -Parent) "tools\flm-seed.mjs")
Remove-Item Env:FLM_SERVER, Env:FLM_DB, Env:FLM_PW -ErrorAction SilentlyContinue

function Test-Up {
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri "http://127.0.0.1:3002/" | Out-Null; return $true } catch { return $false }
}
if (-not (Test-Up)) {
  Write-Host "Subindo gateway na porta 3002..."
  $env:PORT = "3002"
  $env:HOST = "127.0.0.1"
  $env:FREEAPI_DB_PATH = $db
  $env:DASHBOARD_ORIGINS = "http://localhost:5173,http://127.0.0.1:3081,http://127.0.0.1:3002"
  Start-Process -FilePath "node" -ArgumentList @("dist\index.js") -WorkingDirectory (Join-Path $proj "server") `
    -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
  for ($i=0; $i -lt 15; $i++) { Start-Sleep -Seconds 1; if (Test-Up) { break } }
}
Write-Host "[OK] FreeLLMAPI: http://127.0.0.1:3002"
Write-Host "    login: admin@example.com / Freellmapi@2026"
Write-Host "    (log: $log) - rode dsh up e abra o painel do FreeLLMAPI"
