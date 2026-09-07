# dsh-cli.ps1 — comando 'dsh' estilo package-manager (Windows)
# Chamado pela função 'dsh' instalada no perfil do PowerShell.
#   dsh up           abre a GUI principal
#   dsh update       atualiza o repo + core pinado + reaplica pt-BR
#   dsh env create <nome> --core <ver>   |  dsh env remove <nome>
#   dsh env list | import <nome> | freellmapi <nome>
#   dsh core --check | --install <ver> | --rollback <ver>
#   dsh doctor        verifica pré-requisitos e estado
[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Action = "help",
  [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
$ErrorActionPreference = "Stop"
$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent

switch ($Action) {
  "up" {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c", "$Repo\start-dsh-gui.bat"
  }
  "update" {
    git -C $Repo pull --ff-only
    $pinned = (Get-Content (Join-Path $Repo "manifest.json") -Raw | ConvertFrom-Json).core.pinned
    $inst = (& npm ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    if ($inst -notmatch [regex]::Escape($pinned)) {
      & npm install -g "@deepseek-ai/dsh@$pinned"
    } else {
      Write-Host "core ja esta na versao pinada ($pinned)"
    }
    & (Join-Path $Repo "core-i18n-pt\tools\apply-pt-core.ps1") --force
    Write-Host "✔ atualizado. Rode: dsh up"
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
