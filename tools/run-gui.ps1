# run-gui.ps1 - sobe a GUI principal do DeepSeek Harness no Windows (porta 3081)
# Se o servidor ja estiver no ar, so abre o navegador. Usa HOME=%USERPROFILE%\.dsh
param([int]$Port = 3081)
$ErrorActionPreference = "Stop"

function Ensure-Shortcuts {
  param([string]$Repo)
  try {
    $ws = New-Object -ComObject WScript.Shell
    $ico = Join-Path $Repo "assets\deepseek.ico"
    if (-not (Test-Path $ico)) { $ico = "" }
    $tgt = "powershell.exe"
    $args = "-NoProfile -ExecutionPolicy Bypass -File `"" + (Join-Path $Repo "tools\run-gui.ps1") + "`""
    $desk = Join-Path ([Environment]::GetFolderPath("Desktop")) "DeepSeek Harness.lnk"
    $sm = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\DeepSeek Harness.lnk"
    foreach ($p in @($desk, $sm)) {
      $lnk = $ws.CreateShortcut($p)
      $lnk.TargetPath = $tgt
      $lnk.Arguments = $args
      $lnk.WorkingDirectory = $Repo
      $lnk.Description = "DeepSeek Harness (dsh-h-v1)"
      if ($ico) { $lnk.IconLocation = "$ico,0" }
      $lnk.Save()
    }
    Write-Host "[OK] atalhos com icone: Desktop + Menu Iniciar"
  } catch { Write-Host "[i] nao criei atalhos: $($_.Exception.Message)" }
}

function Open-AppWindow {
  param([int]$Port, [string]$profileDir)
  $url = "http://127.0.0.1:$Port"
  $ui = [System.Globalization.CultureInfo]::CurrentUICulture.Name.ToLowerInvariant()
  if ($env:DSH_LANG) { $lang = $env:DSH_LANG }
  elseif ($ui -like "pt*") { $lang = "pt-BR" }
  elseif ($ui -like "zh*") { $lang = "zh-CN" }
  else { $lang = "en-US" }
  Write-Host "[OK] idioma da janela: $lang (segue o idioma do sistema; env DSH_LANG sobrescreve)"
  $cands = @()
  $pf86 = ${env:ProgramFiles(x86)}; $pf = ${env:ProgramFiles}
  if ($pf86) { $cands += (Join-Path $pf86 "Microsoft\Edge\Application\msedge.exe"); $cands += (Join-Path $pf86 "Google\Chrome\Application\chrome.exe") }
  if ($pf) { $cands += (Join-Path $pf "Microsoft\Edge\Application\msedge.exe"); $cands += (Join-Path $pf "Google\Chrome\Application\chrome.exe") }
  foreach ($exe in $cands) {
    if (Test-Path $exe) {
      Start-Process -FilePath $exe -ArgumentList @("--app=$url", "--user-data-dir=$profileDir", "--window-size=1440,900", "--lang=$lang")
      Write-Host "[OK] GUI aberta como janela de app"
      return
    }
  }
  Start-Process $url
  Write-Host "[OK] GUI aberta no navegador (sem Edge/Chrome encontrado)"
}


$bin = Join-Path (& npm.cmd root -g).Trim() "@deepseek-ai\dsh\lib\bin.js"
if (-not (Test-Path $bin)) { Write-Host "[X] core nao encontrado: $bin (rode: npm.cmd install -g @deepseek-ai/dsh)"; exit 1 }
$homeCfg = Join-Path $env:USERPROFILE ".dsh"
if (-not (Test-Path $homeCfg)) { New-Item -ItemType Directory -Force -Path $homeCfg | Out-Null }
$Repo = Split-Path $PSScriptRoot -Parent   # tools/run-gui.ps1 -> <repo>
# Overlay (nossa camada: badges, menu lateral, funcionalidades)
Get-ChildItem -Path (Join-Path $Repo "overlay") -Filter "*.js" | Copy-Item -Destination $homeCfg -Force
# openrouter-enhanced-data.json (lista de modelos do OpenRouter Enhanced; o
# plugin le este arquivo no load e quebra sem ele)
$dataSrc = Join-Path $Repo "overlay\openrouter-enhanced-data.json"
if (Test-Path $dataSrc) { Copy-Item $dataSrc -Destination $homeCfg -Force }
# Assets do editor (CodeMirror/temas/marked/modos) ficam em subpasta e precisam
# ser copiados recursivamente; sem eles o CodeMirror nunca ativa no Windows.
$srcAssets = Join-Path $Repo "overlay\editor-assets"
$dstAssets = Join-Path $homeCfg "editor-assets"
if (Test-Path $srcAssets) {
  if (Test-Path $dstAssets) { Remove-Item $dstAssets -Recurse -Force }
  Copy-Item $srcAssets $dstAssets -Recurse -Force
}
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
# Verifica arquivos do overlay + plugins no cordis (falha aqui = badges somem)
function Test-Overlay([string]$homeCfg) {
  $ok = $true
  foreach ($f in @("smart-router-plugin.js","openrouter-enhanced-plugin.js","model-visibility-plugin.js","openrouter-enhanced-data.json","cordis.patch.yml",".dsh-version.json")) {
    if (-not (Test-Path (Join-Path $homeCfg $f))) { Write-Host "[X] ausente em .dsh: $f"; $ok = $false }
  }
  $cp = Join-Path $homeCfg "cordis.patch.yml"
  if (Test-Path $cp) {
    $txt = Get-Content -Raw $cp
    foreach ($id in @("smart-router","openrouter-enhanced","model-visibility")) {
      if ($txt -notmatch [regex]::Escape("id: $id")) { Write-Host "[X] cordis sem plugin: $id"; $ok = $false }
    }
  }
  if ($ok) { Write-Host "[OK] overlay verificado (.js + data.json + cordis + versao)" }
  else { Write-Host "[i] para corrigir, rode: dsh update" }
  return $ok
}
# Sonda as APIs dos plugins (prova que Roteador/Modelos carregaram de verdade)
function Test-PluginApi([int]$Port, [string]$log) {
  $pairs = @( @("/api/smart-router", "smart-router (Roteador)"), @("/api/model-visibility", "model-visibility (Modelos/consumo)") )
  foreach ($p in $pairs) {
    try {
      $r = Invoke-WebRequest -UseBasicParsing -TimeoutSec 3 -Uri ("http://127.0.0.1:$Port" + $p[0])
      if ($r.StatusCode -eq 200) { Write-Host ("[OK] plugin no ar: " + $p[1]) }
      else { Write-Host ("[X] plugin respondeu " + $r.StatusCode + ": " + $p[1]) }
    } catch { Write-Host ("[X] plugin fora do ar: " + $p[1] + " (veja $log e $log.err)") }
  }
}
Test-Overlay $homeCfg | Out-Null
$started = $false
if (-not (Test-Up)) {
  $env:DSH_HOME = $homeCfg
  $env:DSH_WEB_URL = "http://127.0.0.1:$Port"
  $env:DSH_CLI_LIB = Split-Path $bin -Parent   # plugins acham schemastery/dsh-settings no core
  # resolve bare requires dos plugins p/ os modulos do core (schemastery etc.)
  $npmRoot = (& npm.cmd root -g).Trim()
  $nested  = Join-Path $npmRoot "@deepseek-ai\dsh\node_modules"
  $env:NODE_PATH = ($nested + ";" + $npmRoot)
  Start-Process -FilePath "node" -ArgumentList @("$bin","--profile","web","--no-open","--port","$Port","--host","127.0.0.1") `
    -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError ($log + ".err")
  $started = $true
  for ($i=0; $i -lt 30; $i++) { Start-Sleep -Seconds 1; if (Test-Up) { break } }
}
Write-Host "[OK] GUI: http://127.0.0.1:$Port (log: $log)"
Test-PluginApi $Port $log
Ensure-Shortcuts $Repo
Open-AppWindow $Port (Join-Path $homeCfg "app-profile")
