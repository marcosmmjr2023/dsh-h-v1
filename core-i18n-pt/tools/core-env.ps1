# core-env.ps1 — AMBIENTES PARALELOS do DeepSeek Harness no WINDOWS
# (equivalente ao core-env.sh do Linux; sem pm2 — gerenciamento por registro
#  ~/.dsh-envs/.registry.json com PID/porta/url; Start-Process + launcher .bat)
#
# Uso:
#   core-env.ps1 create <nome> --core <versao> [--from <home>]
#   core-env.ps1 import <nome> [--from <home|env>]
#   core-env.ps1 remove <nome>
#   core-env.ps1 ports
#   core-env.ps1 freellmapi <nome>
#
# A detecção de SO é feita pelo servidor do painel: no Windows ele chama este
# script (powershell.exe -File); no Linux continua o core-env.sh.
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Command = "ports",
  [Parameter(Position = 1)][string]$Name = "",
  [string]$Core = "",
  [string]$From = ""
)
$ErrorActionPreference = "Stop"

$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent   # ...\dsh-h-v1
$Base = Join-Path $env:USERPROFILE ".dsh-envs"
$RegistryFile = Join-Path $Base ".registry.json"
if (-not (Test-Path $Base)) { New-Item -ItemType Directory -Force -Path $Base | Out-Null }
function Read-Registry {
  if (Test-Path $RegistryFile) {
    try { return (Get-Content -Raw $RegistryFile | ConvertFrom-Json) } catch { }
  }
  return @()
}
function Write-Registry([array]$List) { $List | ConvertTo-Json -Depth 6 | Set-Content -Encoding UTF8 $RegistryFile }

function New-Port([int]$Start = 3110, [int]$End = 3900) {
  $used = @()
  Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | ForEach-Object { $used += $_.LocalPort }
  $reg = Read-Registry
  foreach ($r in $reg) { if ($r.Port)   { $used += [int]$r.Port }
                         if ($r.FlmPort){ $used += [int]$r.FlmPort } }
  for ($p = $Start; $p -le $End; $p++) {
    if (($used -notcontains $p) -and @(3000,3001,3002,3003,3080,3081,8125) -notcontains $p) { return $p }
  }
  throw "Sem porta livre na faixa $Start-$End (aumente DSH_PORT_RANGE_END)"
}

function Env-Home([string]$n) { return (Join-Path $Base $n) }
function Entry([string]$n) {
  $reg = Read-Registry
  foreach ($r in $reg) { if ($r.Name -eq $n) { return $r } }
  return $null
}

switch ($Command) {
  "create" {
    if (-not $Name) { throw "Informe o nome (create <nome> --core <versao>)" }
    if (-not $Core) { throw "Informe --core <versao>" }
    $envDir = Env-Home $Name
    if (Test-Path $envDir) { throw "Instancia '$Name' ja existe (remova primeiro)" }
    if (-not $From) { $From = Join-Path $env:USERPROFILE ".dsh-v2" }
    if (-not (Test-Path $From)) { $From = Join-Path $env:USERPROFILE ".dsh" }
    $homeDir = Join-Path $envDir "home"
    $coreDir = Join-Path $envDir "core"
    New-Item -ItemType Directory -Force -Path $homeDir,$coreDir | Out-Null
    $port = New-Port
    Write-Host "▶ criando '$Name' core c$Core porta $port (Linux path inalterado)"
    # 1) copia config do home de origem (sem sessões/storages/node_modules)
    Get-ChildItem -Force $From | ForEach-Object {
      if ($_.Name -in @("sessions","storages","node_modules",".git")) { return }
      Copy-Item -Recurse -Force $_.FullName $homeDir
    }
    # 2) core isolado
    & npm install -g --prefix $coreDir "@deepseek-ai/dsh@$Core" 2>&1 | Write-Host
    $coreRoot = (& npm root -g --prefix $coreDir).Trim()
    # 3) pt-BR via pt-ride (node, multiplataforma)
    $deps = Join-Path $coreRoot "@deepseek-ai\dsh\node_modules\@deepseek-ai"
    if (Test-Path $deps) {
      $env:DSH_PT_SKIP = "dsh-client-ui-conversation"
      & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps 2>&1 | Write-Host
    }
    # 4) meta
    $bin = Join-Path $coreRoot "@deepseek-ai\dsh\lib\bin.js"
    $meta = [ordered]@{ name=$Name; core=$Core; port=$port; url="http://127.0.0.1:$port";
                       home=$homeDir; coreRoot=$coreRoot; created=(Get-Date -Format o) }
    ($meta | ConvertTo-Json) | Set-Content -Encoding UTF8 (Join-Path $envDir "meta.json")
    # 5) inicia (Start-Process com PID no registro)
    $env:DSH_HOME=$homeDir; $env:DSH_WEB_URL="http://127.0.0.1:$port"; $env:DSH_ENV_NAME=$Name; $env:DSH_CORE_VERSION=$Core; $env:HOME=$env:USERPROFILE
    $proc = Start-Process -FilePath "node" -ArgumentList @("$bin","--profile","web","--no-open","--port","$port","--host","127.0.0.1") `
      -WorkingDirectory $env:USERPROFILE -WindowStyle Hidden -PassThru
    $reg = @(Read-Registry) + [ordered]@{ Name=$Name; Port=$port; Pid=$proc.Id; Home=$homeDir; Url=$meta.url }
    Write-Registry @($reg)
    # 6) launcher .bat
    $bat = Join-Path $envDir "abrir-$Name.bat"
    @("@echo off", "REM Abre a instancia $Name (core c$Core) - porta $port",
      "if not exist `"$bin`" goto :eof",
      "start `"`" `"$bin`" --profile web --no-open --port $port --host 127.0.0.1",
      "start http://127.0.0.1:$port") | Set-Content -Encoding ASCII $bat
    Write-Host "✔ instancia '$Name' criada: $($meta.url) (launcher: $bat)"
  }
  "import" {
    if (-not $Name) { throw "Informe o nome (import <nome> [--from <origem>])" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe" }
    if (-not $From) { $From = Join-Path $env:USERPROFILE ".dsh-v2" }
    if (-not (Test-Path $From)) { $From = Join-Path $env:USERPROFILE ".dsh" }
    Write-Host "▶ importando de '$From' p/ '$Name' (mescla)"
    foreach ($sub in @("sessions","storages")) {
      $src = Join-Path $From $sub
      if (Test-Path $src) { Copy-Item -Recurse -Force $src (Join-Path $entry.Home $sub) }
    }
    foreach ($f in @("settings.yaml",".credentials.yaml","cordis.patch.yml")) {
      $src = Join-Path $From $f
      if (Test-Path $src) { Copy-Item -Force $src (Join-Path $entry.Home $f) }
    }
    Write-Host "✔ importacao concluida - recarregue a pagina da instancia (F5)"
  }
  "freellmapi" {
    if (-not $Name) { throw "Informe o nome" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe" }
    $flp = New-Port
    $gw = Join-Path $env:USERPROFILE "projects\freellmapi\server"
    if (Test-Path (Join-Path $gw "dist\index.js")) {
      $flDir = Join-Path (Env-Home $Name) "freellmapi"
      New-Item -ItemType Directory -Force -Path $flDir | Out-Null
      $env:PORT="$flp"; $env:HOST="127.0.0.1"; $env:FREEAPI_DB_PATH=(Join-Path $flDir "freeapi.db")
      $env:DASHBOARD_ORIGINS="http://localhost:5173,http://127.0.0.1:5173,http://127.0.0.1:$($entry.Port)"
      $proc = Start-Process -FilePath "node" -ArgumentList @((Join-Path $gw "dist\index.js")) `
        -WorkingDirectory $gw -WindowStyle Hidden -PassThru
      $reg = @(Read-Registry)
      for ($i=0; $i -lt $reg.Count; $i++) { if ($reg[$i].Name -eq $Name) { $reg[$i].FlmPort=$flp; $reg[$i].FlmPid=$proc.Id } }
      Write-Registry @($reg)
      Write-Host "✔ FreeLLMAPI da instancia na porta $flp"
    } else { Write-Host "ℹ codigo FreeLLMAPI nao encontrado em $gw - use o gateway global" }
  }
  "remove" {
    if (-not $Name) { throw "Informe o nome (remove <nome>)" }
    $entry = Entry $Name
    if (-not $entry) { throw "Instancia '$Name' nao existe" }
    Write-Host "▶ removendo '$Name' (gateway + janela + pasta primeiro; processo por ultimo)"
    if ($entry.FlmPid) { Stop-Process -Id $entry.FlmPid -Force -ErrorAction SilentlyContinue }
    # fecha janela Chrome da instancia (perfil .dsh-envs\<nome> no comando)
    Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
      Where-Object { $_.CommandLine -like "*dsh-envs*$Name*" } |
      ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Remove-Item -Recurse -Force (Env-Home $Name) -ErrorAction SilentlyContinue
    $reg = @(Read-Registry) | Where-Object { $_.Name -ne $Name }
    Write-Registry @($reg)
    if ($entry.Pid) { Stop-Process -Id $entry.Pid -Force -ErrorAction SilentlyContinue }
    Write-Host "✔ instancia '$Name' removida (e atalhos/pasta/perfil)"
  }
  default { # ports
    Write-Host "== Instancias (registro) =="
    foreach ($r in (Read-Registry)) {
      Write-Host ("  {0,-20} harness {1}  flmapi {2}  {3}" -f $r.Name,$r.Port,$r.FlmPort,$r.Url)
    }
    if (-not (Read-Registry)) { Write-Host "  (nenhuma)" }
    Write-Host "proxima porta livre: $((New-Port))"
  }
}
