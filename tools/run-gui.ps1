# run-gui.ps1 - sobe a GUI principal do DeepSeek Harness no Windows (porta 3081)
# Se o servidor ja estiver no ar, so abre o navegador. Usa HOME=%USERPROFILE%\.dsh
param([int]$Port = 3081)
$ErrorActionPreference = "Stop"
$bin = Join-Path (& npm root -g).Trim() "@deepseek-ai\dsh\lib\bin.js"
if (-not (Test-Path $bin)) { Write-Host "[X] core nao encontrado: $bin (rode: npm install -g @deepseek-ai/dsh)"; exit 1 }
$homeCfg = Join-Path $env:USERPROFILE ".dsh"
if (-not (Test-Path $homeCfg)) { New-Item -ItemType Directory -Force -Path $homeCfg | Out-Null }
$Repo = Split-Path $PSScriptRoot -Parent   # tools/run-gui.ps1 -> <repo>
# Overlay (nossa camada: badges, menu lateral, funcionalidades)
Get-ChildItem -Path (Join-Path $Repo "overlay") -Filter "*.js" | Copy-Item -Destination $homeCfg -Force
$tag = (git -C $Repo describe --tags 2>$null | Select-Object -First 1)
if ($tag) {
  @{ version=$tag; updatedAt=(Get-Date -Format o) } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $homeCfg ".dsh-version.json")
}
$log = Join-Path $homeCfg "web.log"
function Test-Up {
  try { $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri "http://127.0.0.1:$Port/" ; return $true } catch { return $false }
}
$started = $false
if (-not (Test-Up)) {
  $env:DSH_HOME = $homeCfg
  $env:DSH_WEB_URL = "http://127.0.0.1:$Port"
  Start-Process -FilePath "node" -ArgumentList @("$bin","--profile","web","--no-open","--port","$Port","--host","127.0.0.1") `
    -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
  $started = $true
  for ($i=0; $i -lt 30; $i++) { Start-Sleep -Seconds 1; if (Test-Up) { break } }
}
Write-Host "[OK] GUI: http://127.0.0.1:$Port (log: $log)"
Start-Process "http://127.0.0.1:$Port"
