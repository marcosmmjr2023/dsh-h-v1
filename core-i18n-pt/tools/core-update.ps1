# core-update.ps1 - atualiza/volta o CORE no WINDOWS (equivalente ao .sh do Linux).
# Sem pm2/sudo: instala no prefixo global do usuario e reaplica pt via pt-ride.
#   core-update.ps1 --check | --history | --install <versao> | --rollback <versao>
param([Parameter(Position=0)][string]$Cmd="--check", [string]$Ver="")
$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ErrorActionPreference = "Stop"
# Nome alinhado ao leitor: o version-badge-plugin.js le ".dsh-core-history.json"
# (o .sh do Linux grava esse mesmo nome; aqui estava "core-history.json").
$HistFile = Join-Path $env:USERPROFILE ".dsh\.dsh-core-history.json"

function Reapply-Pt {
  $root = (& npm.cmd root -g).Trim()
  $deps = Join-Path $root "@deepseek-ai\dsh\node_modules\@deepseek-ai"
  if (Test-Path $deps) {
    if (-not $env:DSH_PT_SKIP) { $env:DSH_PT_SKIP = "" }   # vazio = traduz tudo (inclui a conversa)
    & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps
    return $true
  }
  return $false
}

switch ($Cmd) {
  "--check" {
    $v = (& npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
    Write-Host "core instalado: $v"
  }
  "--history" { if (Test-Path $HistFile) { Get-Content -Encoding UTF8 $HistFile } else { Write-Host "sem historico" } }
  "--install" { if (-not $Ver) { throw "--install <versao>" } }
  "--rollback" { if (-not $Ver) { throw "--rollback <versao>" } }
}
if ($Cmd -in @("--install","--rollback")) {
  $old = ((& npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join "" )
  # npm 11+ bloqueia install scripts (koffi/node-pty); sem o flag o core quebra no boot
  $npmMajor = 0
  try { $npmMajor = [int]((& npm.cmd -v 2>$null).Trim().Split(".")[0]) } catch { }
  $allowFlags = @()
  if ($npmMajor -ge 11) { $allowFlags = @("--allow-scripts=@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs") }
  & npm.cmd install -g "@deepseek-ai/dsh@$Ver" @allowFlags
  $ok = Reapply-Pt
  $h = [ordered]@{ version=$Ver; from=$old; patchesOk=$ok; at=(Get-Date -Format o) }
  # Historico: mais recente primeiro (igual ao core-update.sh) e SEM BOM.
  # -InputObject e obrigatorio: em PS 5.1 o pipe com 1 item gera um OBJETO, e o
  # plugin exige Array (Array.isArray) para mostrar o historico no painel.
  $prev = @()
  if (Test-Path $HistFile) { try { $prev = @(Get-Content -Raw -Encoding UTF8 $HistFile | ConvertFrom-Json) } catch { $prev = @() } }
  $all = @(@($h) + $prev)
  if ($all.Count -gt 12) { $all = $all[0..11] }
  $hj = ConvertTo-Json -InputObject $all -Depth 6
  [System.IO.File]::WriteAllText($HistFile, ($hj + "`r`n"), (New-Object System.Text.UTF8Encoding($false)))
  Write-Host "[OK] core $Ver aplicado (pt-ride: $ok). Abra a GUI pelo atalho (start-dsh-gui.bat)."
}
