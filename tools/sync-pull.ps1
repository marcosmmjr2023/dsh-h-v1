# sync-pull.ps1 — RECEBE atualizações (Windows)
# Puxa o repo e aplica overlay\ sobre a config viva (%USERPROFILE%\.dsh).
# Uso:  powershell -ExecutionPolicy Bypass -File tools\sync-pull.ps1
# Vars: DSH_CLONE (padrão: pasta pai de tools\), DSH_LIVE (padrão: $env:USERPROFILE\.dsh)
$ErrorActionPreference = "Stop"

$SELF    = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE   = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE    = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }

if (-not (Test-Path (Join-Path $CLONE ".git"))) {
    Write-Host "ERRO: $CLONE não é um clone git." -ForegroundColor Red; exit 1
}

Write-Host "▶ sync-pull: $CLONE\overlay → $LIVE"
git -C $CLONE pull --ff-only
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠ Pull falhou. Há alterações locais no clone? (git -C $CLONE status)" -ForegroundColor Yellow
    exit 1
}

# 1) Snapshot do estado ATUAL (para rollback) antes de aplicar
$SNAP_ROOT = if ($env:DSH_SNAP_ROOT) { $env:DSH_SNAP_ROOT } else { Join-Path $env:USERPROFILE ".dsh-snapshots" }
$hash = (git -C $CLONE rev-parse --short HEAD 2>$null)
$snapName = "snap-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $hash
$snapDir  = Join-Path $SNAP_ROOT $snapName
New-Item -ItemType Directory -Force -Path $snapDir | Out-Null
if (Test-Path $LIVE) {
    robocopy $LIVE $snapDir /E /IS /IT /NFL /NDL /NJH /NJS `
        /XD sessions storages `
        /XF .credentials.yaml .credentials.yaml.bak .credentials.yaml.bak-* .anonymous-user-id `
            *.log *.bak *.bak-* state.json *.tpl | Out-Null
    Write-Host "✔ snapshot criado: $snapName"
}
# manutenção: mantém só as 8 mais recentes
Get-ChildItem -Path $SNAP_ROOT -Directory -Filter "snap-*" | Sort-Object Name -Descending |
    Select-Object -Skip 8 | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

# 2) Aplica o overlay novo sobre a config viva
New-Item -ItemType Directory -Force -Path $LIVE | Out-Null
# robocopy: /E copia subpastas; /XD e /XF excluem segredos/estado/backups
robocopy (Join-Path $CLONE "overlay") $LIVE /E /IS /IT /NFL /NDL /NJH /NJS `
    /XD sessions storages `
    /XF .credentials.yaml .credentials.yaml.bak .credentials.yaml.bak-* .anonymous-user-id `
        *.log *.bak *.bak-* state.json
if ($LASTEXITCODE -ge 8) { Write-Host "⚠ robocopy reportou erros (código $LASTEXITCODE)" -ForegroundColor Yellow }

# Gera cordis.patch.yml local a partir do template (caminhos desta máquina)
& (Join-Path $SELF "render-cordis.ps1")
# Grava versão instalada + instante (para o badge de versão)
& (Join-Path $SELF "stamp-version.ps1")

& (Join-Path $SELF "check-core.ps1") 2>$null
Write-Host "✔ sync-pull concluído. Rollback disponível: tools\rollback.ps1 list"
