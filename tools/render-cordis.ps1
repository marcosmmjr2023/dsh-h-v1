# render-cordis.ps1 — gera %USERPROFILE%\.dsh\cordis.patch.yml a partir do
# template overlay\cordis.patch.yml.tpl, substituindo __DSH_HOME__ pelo
# diretório de config vivo DESTA máquina (Windows).
# Uso: powershell -ExecutionPolicy Bypass -File tools\render-cordis.ps1
$ErrorActionPreference = "Stop"
$SELF  = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE  = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }

$TPL = Join-Path $CLONE "overlay\cordis.patch.yml.tpl"
$OUT = Join-Path $LIVE "cordis.patch.yml"
if (-not (Test-Path $TPL)) { exit 0 }

New-Item -ItemType Directory -Force -Path $LIVE | Out-Null
$content = (Get-Content $TPL -Raw).Replace("__DSH_HOME__", $LIVE)
# UTF-8 sem BOM (parser YAML do harness)
[System.IO.File]::WriteAllText($OUT, $content, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "✔ cordis.patch.yml gerado em $OUT"
