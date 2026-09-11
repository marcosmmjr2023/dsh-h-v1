<#
.SYNOPSIS
  auto-sync.ps1 — ciclo completo numa linha (Windows)

.DESCRIPTION
  1) sync-pull.ps1 : recebe do GitHub o que as outras máquinas publicaram
     (snapshot + aplica overlay + stamp de versão)
  2) auto-push.ps1 : publica as suas edições da config viva (documentadas,
     com versão vX.Y.Z e CHANGELOG) — via de mão dupla

  Use como ação única do Agendador de Tarefas (Task Scheduler) ou no
  start-dsh-gui.bat — ex.:
    powershell -ExecutionPolicy Bypass -File "%USERPROFILE%\dsh-h-v1\tools\auto-sync.ps1"
#   Para instalar a tarefa agendada: tools\install-autosync-task.ps1
#   (ou opcao 6 do installer/dsh-setup.ps1).

.NOTES
  Vars: DSH_CLONE (padrão: pasta pai de tools\), DSH_LIVE (padrão: %USERPROFILE%\.dsh)
#>
# Saida em UTF-8 nos dois hosts: com stdout em pipe o PowerShell escreve na codepage
# OEM (cp850/cp1252 no 5.1) e o app le UTF-8 - sem isto o texto acentuado chega
# corrompido no painel. Tem de ser a PRIMEIRA instrucao executavel do script.
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
try { $OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
$ErrorActionPreference = "Continue"
$SELF = Split-Path -Parent $MyInvocation.MyCommand.Path
$LIVE = if ($env:DSH_LIVE) { $env:DSH_LIVE } else { Join-Path $env:USERPROFILE ".dsh" }

# Interruptor ON/OFF (mesmo do badge auto): com o flag presente, pula tudo.
if (Test-Path (Join-Path $LIVE ".dsh-autoupdate.off")) {
    Write-Host "[auto-sync] DESLIGADO (flag presente em $LIVE\.dsh-autoupdate.off) - pulei esta rodada."
    exit 0
}

# Log em arquivo (o Agendador de Tarefas nao tem console; sem log, falha some).
$logFile = Join-Path $LIVE "auto-sync.log"
try { Start-Transcript -Path $logFile -Append -ErrorAction SilentlyContinue | Out-Null } catch { }
try {
    Write-Host "[auto-sync] 1/2 sync-pull (receber)..."
    & (Join-Path $SELF "sync-pull.ps1")

    Write-Host "[auto-sync] 2/2 auto-push (publicar)..."
    & (Join-Path $SELF "auto-push.ps1")

    Write-Host "[auto-sync] concluido."
} finally {
    try { Stop-Transcript -ErrorAction SilentlyContinue | Out-Null } catch { }
}
