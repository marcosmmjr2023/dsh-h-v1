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

.NOTES
  Vars: DSH_CLONE (padrão: pasta pai de tools\), DSH_LIVE (padrão: %USERPROFILE%\.dsh)
#>
$ErrorActionPreference = "Continue"
$SELF = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "[auto-sync] 1/2 sync-pull (receber)..."
& (Join-Path $SELF "sync-pull.ps1")

Write-Host "[auto-sync] 2/2 auto-push (publicar)..."
& (Join-Path $SELF "auto-push.ps1")

Write-Host "[auto-sync] concluído."
