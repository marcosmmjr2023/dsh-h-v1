# render-cordis.ps1 — gera %USERPROFILE%\.dsh\cordis.patch.yml a partir do
# template overlay\cordis.patch.yml.win.tpl (fallback: .tpl do Linux),
# substituindo __DSH_HOME__ pela URL file:/// do diretorio vivo desta maquina
# (o loader ESM exige file:/// no Windows).
# Uso: powershell -ExecutionPolicy Bypass -File tools\render-cordis.ps1
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$ErrorActionPreference = "Stop"
$SELF  = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE  = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }

$TPL = Join-Path $CLONE "overlay\cordis.patch.yml.win.tpl"
if (-not (Test-Path $TPL)) { $TPL = Join-Path $CLONE "overlay\cordis.patch.yml.tpl" }
$OUT = Join-Path $LIVE "cordis.patch.yml"
if (-not (Test-Path $TPL)) { exit 0 }

New-Item -ItemType Directory -Force -Path $LIVE | Out-Null
$homeUrl = "file:///" + ($LIVE -replace "\\", "/")
$content = (Get-Content -Encoding UTF8 $TPL -Raw) -replace "__DSH_HOME__", $homeUrl
# UTF-8 sem BOM (parser YAML do harness)
[System.IO.File]::WriteAllText($OUT, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "✔ cordis.patch.yml gerado em $OUT"
