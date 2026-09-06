<#
.SYNOPSIS
  auto-push.ps1 — PUBLICADOR ROTINEIRO (Windows) — via de MÃO DUPLA

.DESCRIPTION
  Rode em TODA máquina onde você edita o harness: recebe o que as outras
  máquinas publicaram (pull --rebase) e publica as suas edições da config
  viva (%USERPROFILE%\.dsh) — espelhando em overlay\, commitando e fazendo
  push sozinho. Cada publicação sobe DOCUMENTADA sobre a última versão:
    • commit com mensagem descritiva (arquivos alterados);
    • versão automática vX.Y.Z (patch) com tag âncora;
    • CHANGELOG.md do repo atualizado na mesma publicação.
  Conflito entre máquinas: a versão DESTA máquina (última a sincronizar)
  vira a versão atual; a outra fica PRESERVADA no histórico/tag anterior.
  Nunca usa --force. Guardrails: flag .dsh-autoupdate.off desliga; guard
  simples de segredos bloqueia o commit; nunca sobrescreve tag existente.

.PARAMETER DryRun
  Mostra o que seria publicado sem alterar nada.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools\auto-push.ps1
  powershell -ExecutionPolicy Bypass -File tools\auto-push.ps1 -DryRun

.NOTES
  Vars de ambiente: DSH_CLONE (padrão: pasta pai de tools\), DSH_LIVE
  (padrão: $env:USERPROFILE\.dsh)
#>
param([switch]$DryRun)
$ErrorActionPreference = "Stop"

$SELF    = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE   = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE    = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }
$CHLOG   = Join-Path $CLONE "CHANGELOG.md"
$HOST    = $env:COMPUTERNAME

if (-not (Test-Path (Join-Path $CLONE ".git"))) { Write-Host "ERRO: $CLONE não é um clone git." -ForegroundColor Red; exit 1 }
if (-not (Test-Path $LIVE)) { Write-Host "ERRO: config viva $LIVE não existe." -ForegroundColor Red; exit 1 }

# Interruptor ON/OFF (mesmo do auto-update)
if (Test-Path (Join-Path $LIVE ".dsh-autoupdate.off")) {
    Write-Host "⏸ auto-push DESLIGADO (flag presente em $LIVE\.dsh-autoupdate.off)"; exit 0
}

# Lock simples contra concorrência no mesmo clone
$lockPath = Join-Path $CLONE ".git\dsh-autopush.lock"
$fs = $null
try {
    $fs = [System.IO.File]::Open($lockPath, [System.IO.FileMode]::OpenOrCreate,
          [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
} catch {
    Write-Host "⏸ auto-push: outra sincronização em andamento — pulando esta rodada."; exit 0
}

function Get-NextVersion {
    git -C $CLONE fetch --tags -q origin 2>$null | Out-Null
    $cands = @()
    foreach ($t in @(git -C $CLONE tag --list "v[0-9]*")) {
        if ($t -match '^v(\d+)\.(\d+)\.(\d+)$') {
            $cands += [pscustomobject]@{ Tag = $t; Maj = [int]$Matches[1]; Min = [int]$Matches[2]; Pat = [int]$Matches[3] }
        }
    }
    if ($cands.Count -gt 0) {
        $best = $cands | Sort-Object Maj, Min, Pat -Descending | Select-Object -First 1
        return "v$($best.Maj).$($best.Min).$($best.Pat + 1)"
    }
    $mv = Select-String -Path (Join-Path $CLONE "manifest.json") `
             -Pattern '"version"\s*:\s*"([0-9]+\.[0-9]+\.[0-9]+)"' -ErrorAction SilentlyContinue |
         Select-Object -First 1
    if ($mv -and $mv.Matches.Count -gt 0 -and $mv.Matches[0].Groups.Count -gt 1) {
        $parts = $mv.Matches[0].Groups[1].Value.Split(".")
        return "v$($parts[0]).$($parts[1]).$([int]$parts[2] + 1)"
    }
    return "v0.1.1"
}

function Invoke-RebasePull {
    # Conflito: mantém a versão DESTA máquina (última sincronização vence)
    git -C $CLONE pull --rebase -q 2>$null
    if ($LASTEXITCODE -eq 0) { return $true }
    $guardN = 0
    while ((Test-Path (Join-Path $CLONE ".git\rebase-merge")) -or
           (Test-Path (Join-Path $CLONE ".git\rebase-apply"))) {
        $guardN++
        if ($guardN -gt 10) { git -C $CLONE rebase --abort 2>$null | Out-Null; return $false }
        foreach ($f in @(git -C $CLONE diff --name-only --diff-filter=U)) {
            if ($f) {
                Write-Host "   ⚠ conflito em $f → mantida a versão DESTA máquina (a outra fica no histórico)"
                # num rebase, --theirs = o commit local sendo rebaseado (a versão desta máquina)
                git -C $CLONE checkout --theirs -- $f 2>$null
                git -C $CLONE add -- $f
            }
        }
        $env:GIT_EDITOR = "true"
        git -C $CLONE rebase --continue 2>$null | Out-Null
        Remove-Item Env:\GIT_EDITOR -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) { git -C $CLONE rebase --abort 2>$null | Out-Null; return $false }
    }
    return $true
}

function Restore-Overlay {
    git -C $CLONE reset -q -- "overlay" 2>$null
    git -C $CLONE checkout -q -- "overlay" 2>$null
    git -C $CLONE clean -qfd -- "overlay" 2>$null
}

Write-Host "▶ auto-push: $LIVE → $CLONE\overlay (publicação rotineira, via de mão dupla)"

# Dry-run: mostra o que seria espelhado sem alterar nada
if ($DryRun) {
    robocopy $LIVE (Join-Path $CLONE "overlay") /L /E /IS /IT /NFL /NDL /NJH /NJS `
        /XD sessions storages node_modules `
        /XF .credentials.yaml .credentials.yaml.bak .credentials.yaml.bak-* .anonymous-user-id `
            .dsh-version.json .dsh-autoupdate.off *.log *.bak *.bak-* state.json *.tpl
    $ahead = @(git -C $CLONE log "@{u}..HEAD" --oneline 2>$null).Count
    Write-Host "── commits locais ainda não enviados: $ahead ──"
    if ($ahead -gt 0) { git -C $CLONE log "@{u}..HEAD" --oneline }
    Write-Host "── próxima versão estimada: $(Get-NextVersion) ──"
    Write-Host "✔ [dry-run] nada foi alterado."
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 0
}

# 1) Recebe o que as outras máquinas publicaram
if (-not (Invoke-RebasePull)) {
    Write-Host "✋ auto-push ABORTADO: não foi possível integrar o remoto." -ForegroundColor Red
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 1
}

# 2) Espelha a config viva sobre o espelho do clone
robocopy $LIVE (Join-Path $CLONE "overlay") /E /IS /IT /NFL /NDL /NJH /NJS `
    /XD sessions storages node_modules `
    /XF .credentials.yaml .credentials.yaml.bak .credentials.yaml.bak-* .anonymous-user-id `
        .dsh-version.json .dsh-autoupdate.off *.log *.bak *.bak-* state.json *.tpl | Out-Null
if ($LASTEXITCODE -ge 8) { Write-Host "⚠ robocopy reportou erros (código $LASTEXITCODE)" -ForegroundColor Yellow }
# cordis.patch.yml é GERADO por máquina — nunca volta para o repo
Remove-Item -Force (Join-Path $CLONE "overlay\cordis.patch.yml") -ErrorAction SilentlyContinue
git -C $CLONE add -A overlay

# 3) Guard simples de segredos
function Test-StagedClean {
    $staged = git -C $CLONE diff --cached
    if ($staged -match "\.credentials\.yaml" -or
        $staged -match "ghp_[A-Za-z0-9]{20,}" -or
        $staged -match "sk-[A-Za-z0-9]{20,}") { return $false }
    return $true
}
if (-not (Test-StagedClean)) {
    Write-Host "✋ auto-push ABORTADO: possível segredo no staged." -ForegroundColor Red
    Restore-Overlay
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 1
}

# Helpers de saída de comandos git nativos (sem stdout não valem em bool)
function Test-NoStaged {
    git -C $CLONE diff --cached --quiet 2>$null
    return ($LASTEXITCODE -eq 0)
}
function Get-AheadCount {
    $r = git -C $CLONE rev-list --count "@{u}..HEAD" 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $r) { return 0 }
    return [int]$r
}

# 4) Há algo novo? (edição no live OU commits locais pendentes)
$AHEAD_N = Get-AheadCount
if ((Test-NoStaged) -and ($AHEAD_N -eq 0)) {
    Write-Host "ℹ  Nada mudou — nada a publicar."
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 0
}

# 5) Documentação da publicação (sobe junto, sobre a última versão)
$V      = Get-NextVersion
$NOW    = Get-Date -Format "yyyy-MM-dd HH:mm"
$staged = @(git -C $CLONE diff --cached --name-only | Where-Object { $_ -ne "CHANGELOG.md" })
$files  = @($staged | ForEach-Object { $_ -replace "^overlay[\\/]", "" })
$NFILES = $files.Count
$pending = @(git -C $CLONE log "@{u}..HEAD" --oneline 2>$null)

if (-not (Test-Path $CHLOG)) {
    @(
        "# Changelog — camada personalizada do DeepSeek Harness (dsh-h-v1)",
        "",
        "Gerado e versionado automaticamente pelo auto-push (bash/ps1).",
        "Ordem cronológica — a versão mais recente fica no FIM do arquivo.",
        ""
    ) | Set-Content -Path $CHLOG -Encoding UTF8
}
$entry = @(
    "",
    "## [$V] — $NOW (máquina $HOST)",
    "Publicação automática — última sincronização desta máquina."
)
if ($NFILES -gt 0) {
    $entry += "- Arquivos alterados ($NFILES):"
    $entry += $files | ForEach-Object { "  - $_" }
}
if ($pending.Count -gt 0) {
    $entry += "- Commits locais incorporados:"
    $entry += $pending | ForEach-Object { "  - $_" }
}
Add-Content -Path $CHLOG -Value $entry -Encoding UTF8
git -C $CLONE add $CHLOG

# Guard novamente (agora inclui CHANGELOG.md)
if (-not (Test-StagedClean)) {
    Write-Host "✋ auto-push ABORTADO: guard no CHANGELOG/overlay." -ForegroundColor Red
    Restore-Overlay
    git -C $CLONE reset -q -- "CHANGELOG.md" 2>$null
    git -C $CLONE checkout -q -- "CHANGELOG.md" 2>$null
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 1
}

# 6) Mensagem descritiva + commit único (overlay + CHANGELOG)
if ($NFILES -gt 0) {
    $short = ($files | Select-Object -First 4) -join ","
    if ($NFILES -gt 4) { $short = "$short,+$($NFILES - 4) arquivo(s)" }
} else {
    $short = "commits locais publicados"
}
$MSG = "sync(auto): $V — $short"
git -C $CLONE commit -m $MSG
if ($LASTEXITCODE -ne 0) {
    Write-Host "✋ auto-push: commit falhou." -ForegroundColor Red
    Restore-Overlay
    git -C $CLONE reset -q -- "CHANGELOG.md" 2>$null
    git -C $CLONE checkout -q -- "CHANGELOG.md" 2>$null
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 1
}
Write-Host "✔ Commit: $MSG"

# 7) Push (sem --force); rejeitado → rebaseia e tenta de novo
$pushed = $false
foreach ($i in 1..3) {
    git -C $CLONE push -q 2>$null
    if ($LASTEXITCODE -eq 0) { $pushed = $true; break }
    Write-Host "⚠  Push rejeitado (outra máquina publicou antes?) — rebaseando e tentando de novo."
    if (-not (Invoke-RebasePull)) { break }
}
if (-not $pushed) {
    Write-Host "✋ Push falhou após 3 tentativas (autenticação?). Configure gh auth login ou um PAT." -ForegroundColor Yellow
    $fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
    exit 1
}

# 8) Tag de versão (nunca sobrescreve tag existente)
$tagged = $false
foreach ($i in 1..3) {
    $vtag = Get-NextVersion
    git -C $CLONE tag -a $vtag -m $MSG 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "⚠  tag $vtag já existia — tentando a próxima."
        continue
    }
    git -C $CLONE push origin $vtag -q 2>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "✔ Versão publicada: $vtag"; $tagged = $true; break }
    Write-Host "⚠  push da tag $vtag falhou — tentando a próxima."
}
if (-not $tagged) {
    Write-Host "⚠  Commit publicado, mas a tag automática não pôde ser criada agora (a próxima publicação atribui a versão seguinte)."
}
$fs.Dispose(); Remove-Item -Force $lockPath -ErrorAction SilentlyContinue
Write-Host "✔ auto-push concluído: versão local publicada no GitHub."
exit 0
