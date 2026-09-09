# install-autosync-task.ps1 - instala/remove a tarefa agendada do auto-sync (Windows)
#
# Cria a tarefa "DeepSeek Harness AutoSync" no Agendador de Tarefas, que roda
# tools\auto-sync.ps1 a cada N minutos apos o logon (respeita o flag
# %USERPROFILE%\.dsh\.dsh-autoupdate.off do badge auto).
# Sem essa tarefa, o Windows NUNCA atualiza sozinho: o atalho da GUI abre o
# run-gui.ps1 direto (sem git pull) e a versao congela no estado do clone.
#
# Uso:
#   powershell -ExecutionPolicy Bypass -File tools\install-autosync-task.ps1
#   powershell -ExecutionPolicy Bypass -File tools\install-autosync-task.ps1 -Interval 60
#   powershell -ExecutionPolicy Bypass -File tools\install-autosync-task.ps1 -Remove
#   powershell -ExecutionPolicy Bypass -File tools\install-autosync-task.ps1 -Status
param([switch]$Remove, [switch]$Status, [int]$Interval = 30)
$ErrorActionPreference = "Stop"
$TaskName = "DeepSeek Harness AutoSync"
$SELF = Split-Path -Parent $MyInvocation.MyCommand.Path
$CLONE = if ($env:DSH_CLONE) { $env:DSH_CLONE } else { Split-Path -Parent $SELF }
$script = Join-Path $CLONE "tools\auto-sync.ps1"

function Get-Task {
  try { return Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop } catch { return $null }
}

if ($Status) {
  $t = Get-Task
  if ($t) {
    Write-Host ("[i] tarefa existe: $TaskName (estado: " + $t.State + ")")
    try {
      $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
      Write-Host ("[i] ultima execucao: " + $info.LastRunTime + " | resultado: " + $info.LastTaskResult + " | proxima: " + $info.NextRunTime)
    } catch { }
  } else {
    Write-Host "[i] tarefa nao instalada. Rode sem flags para instalar."
  }
  exit 0
}

if ($Remove) {
  $t = Get-Task
  if ($t) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false; Write-Host "[OK] tarefa removida: $TaskName" }
  else { Write-Host "[i] tarefa nao existe: $TaskName" }
  exit 0
}

if (-not (Test-Path $script)) { Write-Host "[X] nao achei $script"; exit 1 }
if ($Interval -lt 5) { $Interval = 5 }
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`"" -WorkingDirectory $CLONE
$trigger = New-ScheduledTaskTrigger -AtLogOn
$rep = New-ScheduledTaskTrigger -Once -At (Get-Date).Date -RepetitionInterval (New-TimeSpan -Minutes $Interval) -RepetitionDuration (New-TimeSpan -Days 1)
$trigger.Repetition = $rep.Repetition
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 20)
try {
  if (Get-Task) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }
  Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Settings $settings -Description "DeepSeek Harness: sync automatico com o GitHub (respeita flag .dsh-autoupdate.off)" | Out-Null
  Write-Host "[OK] tarefa instalada: $TaskName (a cada $Interval min apos logon, por 24h)"
} catch {
  Write-Host "[X] falhou: $($_.Exception.Message)"
  Write-Host "[i] tente rodar este script como Administrador."
  exit 1
}
