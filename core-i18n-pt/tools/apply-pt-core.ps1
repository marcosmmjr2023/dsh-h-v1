# apply-pt-core.ps1 - aplica/verifica o pt-BR no core instalado (WINDOWS).
# Usa o pt-ride.mjs (node, multiplataforma) em vez de patch tooling bash.
#   apply-pt-core.ps1 -Cmd --check | -Cmd --force | -Cmd --revert
#   (sem args = --force)
# ATENCAO: em `powershell.exe -File` o "--flag" cru NAO casa com o parametro
# $Cmd (o PS trata como nome de parametro e falha o binding) — use "-Cmd --flag".
param([Parameter(Position=0)][string]$Cmd="--force")
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$Repo = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$ErrorActionPreference = "Stop"
$root = (& npm.cmd root -g).Trim()
$deps = Join-Path $root "@deepseek-ai\dsh\node_modules\@deepseek-ai"
if (-not (Test-Path $deps)) {
  # tenta tambem o layout plano (some prefixos)
  $deps = Join-Path $root "@deepseek-ai"
}
if ($Cmd -eq "--check") {
  $f = Join-Path $deps "dsh-client-locale\lib\client.js"
  # Le como UTF-8: o Get-Content -Raw -Encoding UTF8 do PS 5.1 interpreta arquivo sem BOM como
  # ANSI e o acento de "Português" vira mojibake, dando falso "ausente".
  $ok = $false
  if (Test-Path $f) {
    try { $ok = ([System.IO.File]::ReadAllText($f, [System.Text.Encoding]::UTF8)) -match 'Portugu[eê]s' } catch { $ok = $false }
  }
  if ($ok) { Write-Host "[OK] pt-BR presente"; exit 0 }
  Write-Host "[X] pt-BR ausente - rode: apply-pt-core.ps1 -Cmd --force"; exit 1
}
if ($Cmd -eq "--force") {
  $env:DSH_PT_SKIP = "dsh-client-ui-conversation"
  & node (Join-Path $Repo "core-i18n-pt\tools\pt-ride.mjs") --root $deps
  if ($LASTEXITCODE -ne 0) { Write-Host "[X] pt-ride falhou (veja acima)"; exit 1 }
  Write-Host "[OK] pt-BR garantido via pt-ride"
}
