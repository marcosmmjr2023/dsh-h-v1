# apply-pt-core.ps1 - aplica/verifica o pt-BR no core instalado (WINDOWS).
# Usa o pt-ride.mjs (node, multiplataforma) em vez de patch tooling bash.
#   apply-pt-core.ps1 --check | --force | --revert
param([Parameter(Position=0)][string]$Cmd="--force")
$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ErrorActionPreference = "Stop"
$root = (& npm root -g).Trim()
$deps = Join-Path $root "@deepseek-ai\dsh\node_modules\@deepseek-ai"
if (-not (Test-Path $deps)) {
  # tenta tambem o layout plano (some prefixos)
  $deps = Join-Path $root "@deepseek-ai"
}
if ($Cmd -eq "--check") {
  $f = Join-Path $deps "dsh-client-locale\lib\client.js"
  if ((Test-Path $f) -and ((Get-Content -Raw $f) -match 'Portugues')) { Write-Host "[OK] pt-BR presente"; exit 0 }
  Write-Host "[X] pt-BR ausente - rode apply-pt-core.ps1 --force"; exit 1
}
if ($Cmd -eq "--force") {
  $env:DSH_PT_SKIP = "dsh-client-ui-conversation"
  & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps
  Write-Host "[OK] pt-BR garantido via pt-ride"
}
