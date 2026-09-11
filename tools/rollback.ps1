# rollback.ps1 — volta para uma versão ANTERIOR que funcionava (Windows)
#   list                → snapshots locais + tags/commits disponíveis
#   --snapshot <nome>   → restaura config viva de um snapshot local
#   <tag|commit>        → volta o overlay àquela versão do repo
#   --core <versão>     → reinstala o core (npm)
# Vars: DSH_CLONE, DSH_LIVE, DSH_SNAP_ROOT
param([string]$Cmd = "list", [string]$Arg = "")
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }

$ErrorActionPreference = "Stop"
$SELF      = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE     = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$LIVE      = if ($env:DSH_LIVE)  { $env:DSH_LIVE  } else { Join-Path $env:USERPROFILE ".dsh" }
$SNAP_ROOT = if ($env:DSH_SNAP_ROOT) { $env:DSH_SNAP_ROOT } else { Join-Path $env:USERPROFILE ".dsh-snapshots" }
$MANAGED   = Join-Path $CLONE "overlay"

if (-not (Test-Path (Join-Path $CLONE ".git"))) { Write-Host "ERRO: $CLONE não é um clone git." -ForegroundColor Red; exit 1 }

$XD = "/XD", "sessions", "storages"
$XF = "/XF", ".credentials.yaml", ".credentials.yaml.bak", ".credentials.yaml.bak-*", ".anonymous-user-id",
          "*.log", "*.bak", "*.bak-*", "state.json", "*.tpl"

function New-Snapshot {
    $hash = (git -C $CLONE rev-parse --short HEAD 2>$null)
    $name = "snap-" + (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $hash
    $dest = Join-Path $SNAP_ROOT $name
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    if (Test-Path $LIVE) { robocopy $LIVE $dest /E /IS /IT $XD $XF /NFL /NDL /NJH /NJS | Out-Null }
    Write-Host "  (estado atual salvo em snapshot $name antes do rollback)"
}

switch ($Cmd) {
    "list" {
        Write-Host "═ Snapshots locais ($SNAP_ROOT) ═" -ForegroundColor Cyan
        $snaps = Get-ChildItem -Path $SNAP_ROOT -Directory -Filter "snap-*" -ErrorAction SilentlyContinue |
                 Sort-Object Name -Descending
        if ($snaps) { $snaps | ForEach-Object { Write-Host "  $($_.Name)" } }
        else { Write-Host "  (nenhum snapshot ainda)" }
        Write-Host ""
        Write-Host "═ Tags (versões publicadas) ═" -ForegroundColor Cyan
        $tags = git -C $CLONE tag
        if ($tags) { $tags | ForEach-Object { Write-Host "  $_" } } else { Write-Host "  (nenhuma tag)" }
        Write-Host ""
        Write-Host "═ Commits recentes do overlay ═" -ForegroundColor Cyan
        git -C $CLONE log --oneline -12 | ForEach-Object { Write-Host "  $_" }
        Write-Host ""
        Write-Host "Uso:"
        Write-Host "  tools\rollback.ps1 --snapshot <nome>   restaurar um snapshot local"
        Write-Host "  tools\rollback.ps1 <tag|commit>        voltar o overlay a uma versão do repo"
        Write-Host "  tools\rollback.ps1 --core <versão>     reinstalar o core (npm)"
    }
    "--snapshot" {
        if (-not $Arg) { Write-Host "ERRO: informe o snapshot (rollback.ps1 list)" -ForegroundColor Red; exit 2 }
        New-Snapshot
        $dest = Join-Path $SNAP_ROOT $Arg
        if (-not (Test-Path $dest)) { Write-Host "ERRO: snapshot '$Arg' não encontrado." -ForegroundColor Red; exit 1 }
        Write-Host "▶ Restaurando snapshot: $Arg → $LIVE"
        robocopy $dest $LIVE /E /PURGE /IS /IT $XD $XF /NFL /NDL /NJH /NJS
        if ($LASTEXITCODE -ge 8) { Write-Host "⚠ robocopy: código $LASTEXITCODE" -ForegroundColor Yellow }
        Write-Host "✔ Config viva restaurada. Reinicie o harness."
    }
    "--core" {
        if (-not $Arg) { Write-Host "ERRO: informe a versão (ex.: --core 0.1.1-rc.2)" -ForegroundColor Red; exit 2 }
        Write-Host "▶ Reinstalando core @deepseek-ai/dsh@$Arg"
        npm.cmd install -g "@deepseek-ai/dsh@$Arg"
        if ($LASTEXITCODE -ne 0) { Write-Host "ERRO: npm install falhou (exit $LASTEXITCODE)." -ForegroundColor Red; exit 1 }
        # reinstalar o pacote APAGA a traducao pt-BR (os arquivos vem do npm):
        # reaplica em seguida, como fazem core-update.ps1/dsh-cli.ps1 update.
        $applyPt = Join-Path $SELF "..\core-i18n-pt\tools\apply-pt-core.ps1"
        if (Test-Path $applyPt) {
            & $applyPt -Cmd --force
            if ($LASTEXITCODE -ne 0) { Write-Host "[AVISO] pt-BR nao reaplicado - rode depois: dsh pt" -ForegroundColor Yellow }
        }
        Write-Host "✔ Core $Arg instalado (pt-BR reaplicado). Teste os plugins."
    }
    default {
        # <tag|commit>
        git -C $CLONE rev-parse --verify "${Cmd}^{commit}" *> $null
        if ($LASTEXITCODE -ne 0) { Write-Host "ERRO: '$Cmd' não é tag/commit válido." -ForegroundColor Red; exit 1 }
        New-Snapshot
        Write-Host "▶ Voltando overlay para: $Cmd"

        # Arquivos que existem no HEAD atual mas não no ref → remover
        $now = (git -C $CLONE ls-tree -r --name-only HEAD -- overlay) | Sort-Object
        $old = (git -C $CLONE ls-tree -r --name-only $Cmd -- overlay) | Sort-Object
        $removed = Compare-Object $now $old | Where-Object { $_.SideIndicator -eq "<=" } |
                   ForEach-Object { $_.InputObject }
        foreach ($f in $removed) {
            $rel = $f.Substring("overlay/".Length)
            Remove-Item -Force (Join-Path $CLONE $f) -ErrorAction SilentlyContinue
            Remove-Item -Force (Join-Path $LIVE $rel) -ErrorAction SilentlyContinue
            Write-Host "  removido: $rel"
        }

        # Conteúdo do ref → espelho → config viva
        $tmp = Join-Path $env:TEMP ("rollback-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        # git archive escreve o zip direto no arquivo: evita o pipeline binario e
        # o "-Encoding Byte", que existe no Windows PowerShell 5.1 mas NAO no 7+
        # (no 7 seria "-AsByteStream") — assim roda igual nos dois hosts.
        git -C $CLONE archive --format=zip -o (Join-Path $tmp "o.zip") $Cmd overlay
        Expand-Archive -Path (Join-Path $tmp "o.zip") -DestinationPath $tmp -Force
        robocopy (Join-Path $tmp "overlay") $MANAGED /E /IS /IT /NFL /NDL /NJH /NJS | Out-Null
        robocopy $MANAGED $LIVE /E /IS /IT $XD $XF /NFL /NDL /NJH /NJS | Out-Null
        Remove-Item -Recurse -Force $tmp
        # regenera cordis.patch.yml local (caminhos desta máquina) conforme o ref
        & (Join-Path $SELF "render-cordis.ps1")
        # grava a versão do REF (o badge mostra para qual versão você voltou)
        & (Join-Path $SELF "stamp-version.ps1") -Ref $Cmd
        Write-Host "✔ Overlay restaurado para $Cmd. Reinicie o harness."
        $pinned = (git -C $CLONE show "${Cmd}:manifest.json" 2>$null | ConvertFrom-Json).core.pinned
        if ($pinned) { Write-Host "  core pinado em $Cmd = $pinned — se precisar: tools\rollback.ps1 --core $pinned" }
    }
}
