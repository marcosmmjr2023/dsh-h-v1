# stamp-version.ps1 — grava %USERPROFILE%\.dsh\.dsh-version.json com a versão
# instalada do overlay (tag/commit do clone) e o instante da atualização.
# Chamado pelo sync-pull.ps1 e rollback.ps1 (o badge de versão lê este arquivo).
# O arquivo é LOCAL da máquina — nunca entra no repo (sync-excludes).
$ErrorActionPreference = "Stop"
$SELF  = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE  = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }

$VER = (git -C $CLONE describe --tags --abbrev=0 2>$null)
if (-not $VER) { $VER = (git -C $CLONE rev-parse --short HEAD 2>$null) }
if (-not $VER) { $VER = "dev" }
$SHA = (git -C $CLONE rev-parse HEAD 2>$null)
if (-not $SHA) { $SHA = "?" }
$TS  = [DateTime]::UtcNow.ToString("o")

New-Item -ItemType Directory -Force -Path $LIVE | Out-Null
$json = '{"version":"' + $VER + '","commit":"' + $SHA + '","updatedAt":"' + $TS + '"}'
[System.IO.File]::WriteAllText((Join-Path $LIVE ".dsh-version.json"), $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Host "✔ versão gravada em $LIVE\.dsh-version.json: $VER ($TS)"
