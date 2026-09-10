# dsh-cli.ps1 - comando 'dsh' estilo package-manager (Windows)
# Chamado pela funcao 'dsh' instalada no perfil do PowerShell.
#   dsh up           abre a GUI principal
#   dsh update       atualiza o repo + core pinado + reaplica pt-BR
#   dsh env create <nome> --core <ver>   |  dsh env remove <nome>
#   dsh env list | import <nome> | freellmapi <nome>
#   dsh core --check | --install <ver> | --rollback <ver>
#   dsh doctor        verifica pre-requisitos e estado
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Action = "help",
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent   # dsh-cli.ps1 fica em <repo>/tools

switch ($Action) {
  "up" {
    & (Join-Path $Repo "tools\run-gui.ps1")
  }
  "sync-overlay" {
    $homeCfg = Join-Path $env:USERPROFILE ".dsh"
    if (-not (Test-Path $homeCfg)) { New-Item -ItemType Directory -Force -Path $homeCfg | Out-Null }
    Get-ChildItem -Path (Join-Path $Repo "overlay") -Filter "*.js" | Copy-Item -Destination $homeCfg -Force
    # openrouter-enhanced-data.json (lista de modelos do OpenRouter Enhanced; o
    # plugin le este arquivo no load e quebra sem ele)
    $dataSrc = Join-Path $Repo "overlay\openrouter-enhanced-data.json"
    if (Test-Path $dataSrc) { Copy-Item $dataSrc -Destination $homeCfg -Force }
    # editor-assets (CodeMirror/temas/marked/modos) tambem precisam ir (subpasta)
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
    }
    Write-Host "[OK] overlay sincronizado em $homeCfg (cordis.patch.yml gerado)"
  }
  "update" {
    git -C $Repo pull --ff-only
    & (Join-Path $Repo "tools\dsh-cli.ps1") "sync-overlay"
    $pinned = (Get-Content (Join-Path $Repo "manifest.json") -Raw | ConvertFrom-Json).core.pinned
    $inst = (& npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    if ($inst -notmatch [regex]::Escape($pinned)) {
      & npm.cmd install -g "@deepseek-ai/dsh@$pinned"
    } else {
      Write-Host "core ja esta na versao pinada ($pinned)"
    }
    & (Join-Path $Repo "core-i18n-pt\tools\apply-pt-core.ps1") --force
    # Reaplica o provider "meta" no catalogo do core (pi-ai) apos update
    try {
      & (Join-Path $Repo "tools\piai-meta-patch.ps1")
    } catch {
      Write-Host "[i] piai-meta: nao aplicado (rode manualmente: tools\piai-meta-patch.ps1)"
    }
    Write-Host "[OK] atualizado. Rode: dsh up"
  }
  "env" {
    if ($Rest.Count -eq 0) { $Rest = @("ports") }
    & (Join-Path $Repo "core-i18n-pt\tools\core-env.ps1") @Rest
  }
  "core" {
    & (Join-Path $Repo "core-i18n-pt\tools\core-update.ps1") @Rest
  }
  "flm-setup" {
    & (Join-Path $Repo "tools\flm-setup.ps1")
  }
  "doctor" {
    Write-Host "node:   $(& node -v)"
    Write-Host "npm:    $(& npm.cmd -v)"
    Write-Host "git:    $(& git --version)"
    $core = (& npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    Write-Host "core:   $core"
    $ok = & (Join-Path $Repo "core-i18n-pt\tools\apply-pt-core.ps1") --check
    Write-Host "repo:   $Repo"
    $homeCfg = Join-Path $env:USERPROFILE ".dsh"
    foreach ($f in @("smart-router-plugin.js","openrouter-enhanced-plugin.js","model-visibility-plugin.js","openrouter-enhanced-data.json","cordis.patch.yml",".dsh-version.json")) {
      if (Test-Path (Join-Path $homeCfg $f)) { Write-Host "[OK] .dsh/$f" }
      else { Write-Host "[X] ausente: .dsh/$f  -> rode: dsh update" }
    }
    $cp = Join-Path $homeCfg "cordis.patch.yml"
    if (Test-Path $cp) {
      $txt = Get-Content -Raw $cp
      foreach ($id in @("smart-router","openrouter-enhanced","model-visibility")) {
        if ($txt -match [regex]::Escape("id: $id")) { Write-Host "[OK] cordis: $id" }
        else { Write-Host "[X] cordis sem: $id  -> rode: dsh update" }
      }
    }
    $ver = Join-Path $homeCfg ".dsh-version.json"
    if (Test-Path $ver) { Write-Host ("badge versao: " + ((Get-Content -Raw $ver | ConvertFrom-Json).version)) }
    else { Write-Host "[X] sem .dsh-version.json (badge mostra v?)" }
    foreach ($p in @("smart-router-plugin.js","openrouter-enhanced-plugin.js","model-visibility-plugin.js")) {
      $fp = Join-Path $homeCfg $p
      if (Test-Path $fp) {
        & node --check $fp 2>$null
        if ($LASTEXITCODE -eq 0) { Write-Host "[OK] sintaxe: $p" } else { Write-Host "[X] sintaxe quebrada: $p" }
      }
    }
    $cmd = Get-Command dsh -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.CommandType -eq "Function") { Write-Host "[OK] comando dsh: funcao do perfil" }
    else {
      Write-Host "[X] comando dsh cai no shim do core (npm) em vez da funcao do perfil"
      Write-Host "    -> reabra o PowerShell (a funcao carrega do perfil) ou rode direto:"
      Write-Host ("    powershell -ExecutionPolicy Bypass -File `"" + (Join-Path $Repo "tools\dsh-cli.ps1") + "`" doctor")
    }
  }
  default {
    Write-Host "uso: dsh up | dsh update | dsh env ... | dsh core ... | dsh doctor"
  }
}
