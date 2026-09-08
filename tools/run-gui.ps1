# run-gui.ps1 - sobe a GUI principal do DeepSeek Harness no Windows (porta 3081)
# Se o servidor ja estiver no ar, so abre o navegador. Usa HOME=%USERPROFILE%\.dsh
param([int]$Port = 3081)
$ErrorActionPreference = "Stop"

function Remove-FailingPlugins([string]$yaml) {
  $bad = @("id: smart-router", "id: openrouter-enhanced", "id: model-visibility")
  $paras = $yaml -split "(?m)^\s*$"
  $keep = New-Object System.Collections.Generic.List[string]
  foreach ($p in $paras) {
    $skip = $false
    foreach ($b in $bad) { if ($p -match [regex]::Escape($b)) { $skip = $true; break } }
    if (-not $skip) { $keep.Add($p) }
  }
  return ($keep -join "`r`n")
}

$bin = Join-Path (& npm root -g).Trim() "@deepseek-ai\dsh\lib\bin.js"
if (-not (Test-Path $bin)) { Write-Host "[X] core nao encontrado: $bin (rode: npm install -g @deepseek-ai/dsh)"; exit 1 }
$homeCfg = Join-Path $env:USERPROFILE ".dsh"
if (-not (Test-Path $homeCfg)) { New-Item -ItemType Directory -Force -Path $homeCfg | Out-Null }
$Repo = Split-Path $PSScriptRoot -Parent   # tools/run-gui.ps1 -> <repo>
# Overlay (nossa camada: badges, menu lateral, funcionalidades)
Get-ChildItem -Path (Join-Path $Repo "overlay") -Filter "*.js" | Copy-Item -Destination $homeCfg -Force
$tpl = Join-Path $Repo "overlay\cordis.patch.yml.win.tpl"
if (-not (Test-Path $tpl)) { $tpl = Join-Path $Repo "overlay\cordis.patch.yml.tpl" }
if (Test-Path $tpl) {
  $homeUrl = "file:///" + ($homeCfg -replace "\\", "/")   # loader ESM exige file:/// no Windows
  (Get-Content -Raw $tpl) -replace "__DSH_HOME__", $homeUrl | Set-Content -Encoding UTF8 (Join-Path $homeCfg "cordis.patch.yml")
  Write-Host "[OK] cordis.patch.yml gerado em $homeCfg"
}
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
  $env:DSH_CLI_LIB = Split-Path $bin -Parent   # plugins acham schemastery/dsh-settings no core
  # resolve bare requires dos plugins p/ os modulos do core (schemastery etc.)
  $npmRoot = (& npm root -g).Trim()
  $nested  = Join-Path $npmRoot "@deepseek-ai\dsh\node_modules"
  $env:NODE_PATH = ($nested + ";" + $npmRoot)
  Start-Process -FilePath "node" -ArgumentList @("$bin","--profile","web","--no-open","--port","$Port","--host","127.0.0.1") `
    -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
  $started = $true
  for ($i=0; $i -lt 30; $i++) { Start-Sleep -Seconds 1; if (Test-Up) { break } }
}
Write-Host "[OK] GUI: http://127.0.0.1:$Port (log: $log)"
Start-Process "http://127.0.0.1:$Port"
