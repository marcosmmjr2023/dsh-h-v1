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

$Repo = Split-Path $PSScriptRoot -Parent   # dsh-cli.ps1 fica em <repo>/tools

switch ($Action) {
  "up" {
    & (Join-Path $Repo "tools\run-gui.ps1")
  }
  "sync-overlay" {
    $homeCfg = Join-Path $env:USERPROFILE ".dsh"
    if (-not (Test-Path $homeCfg)) { New-Item -ItemType Directory -Force -Path $homeCfg | Out-Null }
    Get-ChildItem -Path (Join-Path $Repo "overlay") -Filter "*.js" | Copy-Item -Destination $homeCfg -Force
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
    $inst = (& npm ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    if ($inst -notmatch [regex]::Escape($pinned)) {
      & npm install -g "@deepseek-ai/dsh@$pinned"
    } else {
      Write-Host "core ja esta na versao pinada ($pinned)"
    }
    & (Join-Path $Repo "core-i18n-pt\tools\apply-pt-core.ps1") --force
    Write-Host "[OK] atualizado. Rode: dsh up"
  }
  "env" {
    if ($Rest.Count -eq 0) { $Rest = @("ports") }
    & (Join-Path $Repo "core-i18n-pt\tools\core-env.ps1") @Rest
  }
  "core" {
    & (Join-Path $Repo "core-i18n-pt\tools\core-update.ps1") @Rest
  }
  "doctor" {
    Write-Host "node:   $(& node -v)"
    Write-Host "npm:    $(& npm -v)"
    Write-Host "git:    $(& git --version)"
    $core = (& npm ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    Write-Host "core:   $core"
    $ok = & (Join-Path $Repo "core-i18n-pt\tools\apply-pt-core.ps1") --check
    Write-Host "repo:   $Repo"
  }
  default {
    Write-Host "uso: dsh up | dsh update | dsh env ... | dsh core ... | dsh doctor"
  }
}
