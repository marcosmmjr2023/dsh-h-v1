# core-update.ps1 — atualiza/volta o CORE no WINDOWS (equivalente ao .sh do Linux).
# Sem pm2/sudo: instala no prefixo global do usuário e reaplica pt via pt-ride.
#   core-update.ps1 --check | --history | --install <versao> | --rollback <versao>
param([Parameter(Position=0)][string]$Cmd="--check", [string]$Ver="")
$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ErrorActionPreference = "Stop"
$HistFile = Join-Path $env:USERPROFILE ".dsh\core-history.json"

function Reapply-Pt {
  $root = (& npm root -g).Trim()
  $deps = Join-Path $root "@deepseek-ai\dsh\node_modules\@deepseek-ai"
  if (Test-Path $deps) {
    $env:DSH_PT_SKIP = "dsh-client-ui-conversation"
    & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps
    return $true
  }
  return $false
}

switch ($Cmd) {
  "--check" {
    $v = (& npm ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    Write-Host "core instalado: $v"
  }
  "--history" { if (Test-Path $HistFile) { Get-Content $HistFile } else { Write-Host "sem historico" } }
  "--install" { if (-not $Ver) { throw "--install <versao>" } }
  "--rollback" { if (-not $Ver) { throw "--rollback <versao>" } }
}
if ($Cmd -in @("--install","--rollback")) {
  $old = ((& npm ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join "" )
  & npm install -g "@deepseek-ai/dsh@$Ver"
  $ok = Reapply-Pt
  $h = [ordered]@{ version=$Ver; from=$old; patchesOk=$ok; at=(Get-Date -Format o) }
  @($h) | ConvertTo-Json | Set-Content -Encoding UTF8 $HistFile
  Write-Host "✔ core $Ver aplicado (pt-ride: $ok). Abra a GUI pelo atalho (start-dsh-gui.bat)."
}
