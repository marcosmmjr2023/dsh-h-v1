# sync-push.ps1 — PUBLICA suas edições locais (Windows)
# Copia a config viva (%USERPROFILE%\.dsh) para o espelho overlay\ do clone
# e faz commit+push (segredos/estado sempre excluídos + guard simples).
# Uso:  powershell -ExecutionPolicy Bypass -File tools\sync-push.ps1 "mensagem"
$ErrorActionPreference = "Stop"

$SELF    = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE   = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE    = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }
$MSG     = if ($args.Count -gt 0) { $args[0] } else { "sync: atualização da camada personalizada" }

if (-not (Test-Path (Join-Path $CLONE ".git"))) { Write-Host "ERRO: $CLONE não é um clone git." -ForegroundColor Red; exit 1 }
if (-not (Test-Path $LIVE)) { Write-Host "ERRO: config viva $LIVE não existe." -ForegroundColor Red; exit 1 }

Write-Host "▶ sync-push: $LIVE → $CLONE\overlay"
git -C $CLONE pull --rebase 2>$null

robocopy $LIVE (Join-Path $CLONE "overlay") /E /IS /IT /NFL /NDL /NJH /NJS `
    /XD sessions storages `
    /XF .credentials.yaml .credentials.yaml.bak .credentials.yaml.bak-* .anonymous-user-id `
        *.log *.bak *.bak-* state.json *.tpl
if ($LASTEXITCODE -ge 8) { Write-Host "⚠ robocopy reportou erros (código $LASTEXITCODE)" -ForegroundColor Yellow }

# cordis.patch.yml é GERADO por máquina (nunca volta para o repo)
Remove-Item -Force (Join-Path $CLONE "overlay\cordis.patch.yml") -ErrorAction SilentlyContinue

git -C $CLONE add -A overlay

# Guard simples (Windows): bloqueia .credentials.yaml e prefixos de chave no staged
$staged = git -C $CLONE diff --cached
if ($staged -match "\.credentials\.yaml" -or $staged -match "ghp_[A-Za-z0-9]{20,}" -or $staged -match "sk-[A-Za-z0-9]{20,}") {
    Write-Host "✋ sync-push ABORTADO: possível segredo no staged. Revise e remova." -ForegroundColor Red
    exit 1
}

if (-not (git -C $CLONE diff --cached --quiet)) {
    git -C $CLONE commit -m $MSG
    git -C $CLONE push
    if ($LASTEXITCODE -ne 0) {
        Write-Host "✋ Push falhou (autenticação?). Configure gh auth login ou um PAT no credential helper." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "✔ Publicado: $MSG"
} else {
    Write-Host "ℹ Nada mudou — nada a publicar."
}
Write-Host "✔ sync-push concluído."
