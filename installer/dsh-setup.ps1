# dsh-setup.ps1 - Instalador COMPLETO e INTERATIVO do DeepSeek Harness (Windows)
# Detecta o que existe, mostra o estado e pergunta antes de instalar/limpar.
#
# 1 linha (se o PowerShell bloquear scripts, use o Bypass):
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.ps1 | iex"
#
# Modos nao-interativos: -Clean | -Update | -ListInstances | -RemoveAllInstances | -Open | -Doctor
param([string]$Mode = "")
$ErrorActionPreference = "Stop"
$GH = "https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer"
$Repo = Join-Path $env:USERPROFILE "projects\dsh\dsh-h-v1"
$HomeCfg = Join-Path $env:USERPROFILE ".dsh"
$RegFile = Join-Path $env:USERPROFILE ".dsh-envs\.registry.json"

function Say($m) { Write-Host $m }
function Ask([string]$msg) { Write-Host -NoNewline ($msg + " "); return (Read-Host) }
function Detect {
  $r = [ordered]@{}
  $r.node = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
  $r.git  = (Get-Command git  -ErrorAction SilentlyContinue) -ne $null
  $r.repo = Test-Path (Join-Path $Repo ".git")
  $tag = ""; if ($r.repo) { $tag = (git -C $Repo describe --tags 2>$null | Select-Object -First 1) }
  $r.repoTag = $tag
  $core = (& npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
  $r.core = $core -match "@deepseek-ai/dsh"
  $r.cfg = (Test-Path (Join-Path $HomeCfg "cordis.patch.yml")) -or (Test-Path (Join-Path $HomeCfg ".dsh-version.json"))
  $r.flmCode = Test-Path (Join-Path $env:USERPROFILE "projects\freellmapi\server\dist\index.js")
  try { Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 -Uri "http://127.0.0.1:3002/" | Out-Null; $r.flmUp = $true } catch { $r.flmUp = $false }
  $r.instances = @()
  if (Test-Path $RegFile) {
    try { $r.instances = @((Get-Content -Raw -Encoding UTF8 $RegFile | ConvertFrom-Json)) } catch { }
  }
  $alias = if (Test-Path $PROFILE) { (Get-Content -Encoding UTF8 $PROFILE -Raw -ErrorAction SilentlyContinue) -match "function dsh" } else { $false }
  $r.dshAlias = $alias
  return $r
}
function Show-State($s) {
  Say ""
  Say "====================================================="
  Say " ESTADO DA MAQUINA (DeepSeek Harness)"
  Say "====================================================="
  Say (" Node/npm:      " + $(if ($s.node) { "[OK]" } else { "[FALTA]" }))
  Say (" Git:           " + $(if ($s.git)  { "[OK]" } else { "[FALTA]" }))
  Say (" Repo local:    " + $(if ($s.repo) { "[OK] $($s.repoTag)" } else { "[ausente]" }))
  Say (" Core global:   " + $(if ($s.core) { "[OK]" } else { "[ausente]" }))
  Say (" Config (home): " + $(if ($s.cfg)  { "[OK]" } else { "[ausente]" }))
  Say (" FreeLLMAPI:    " + $(if ($s.flmUp) { "[no ar :3002]" } elseif ($s.flmCode) { "[codigo ok, parado]" } else { "[ausente]" }))
  Say (" Comando dsh:   " + $(if ($s.dshAlias) { "[OK]" } else { "[nao instalado]" }))
  if ($s.instances.Count -gt 0) {
    Say (" Instancias:    " + $s.instances.Count)
    foreach ($e in $s.instances) { Say ("   - " + $e.Name + "  (porta " + $e.Port + ")" + $(if ($e.Pid) { " PID " + $e.Pid } else { "" })) }
  } else { Say " Instancias:    nenhuma" }
  Say "====================================================="
}
function Run-Remote($script) {
  iex (irm ($GH + "/" + $script) )
}
function Do-CleanInstall {
  Say ""
  Say "[ATENCAO] Isso apaga da SUA maquina:"
  Say "  - repo      $Repo"
  Say "  - config    $HomeCfg"
  Say "  - instancias e atalhos do harness"
  Say "  - core global @deepseek-ai/dsh"
  Say "Depois instala TUDO limpo do repositorio."
  $c = Ask "Digite 'limpar' para confirmar (ou Enter para cancelar):"
  if ($c -ne "limpar") { Say "Cancelado."; return }
  Run-Remote "clean-windows.ps1"
  Run-Remote "install-windows.ps1"
}
function Do-Update {
  Say "Atualizando/completando a instalacao existente (nao apaga nada)..."
  Run-Remote "install-windows.ps1"
}
function Show-Instances {
  $s = Detect
  if ($s.instances.Count -eq 0) { Say "Nenhuma instancia detectada."; return }
  Say "Instancias detectadas:"
  $i = 1
  foreach ($e in $s.instances) { Say ("  $i) " + $e.Name + "  (porta " + $e.Port + ")"); $i++ }
  Say "  0) Cancelar"
}
function Remove-OneInstance {
  $n = Ask "Nome da instancia para desinstalar (ex.: nova-012rc1):"
  if (-not $n) { return }
  if (Test-Path (Join-Path $Repo "core-i18n-pt\tools\core-env.ps1")) {
    & (Join-Path $Repo "core-i18n-pt\tools\core-env.ps1") remove $n
  } else { Say "[X] repo ausente - rode antes dsh-setup (opcao B) para baixar." }
}
function Do-RemoveAll {
  $s = Detect
  if ($s.instances.Count -eq 0) { Say "Nenhuma instancia."; return }
  $c = Ask ("Apagar TODAS as " + $s.instances.Count + " instancias? Digite 'apagar' para confirmar:")
  if ($c -ne "apagar") { return }
  foreach ($e in $s.instances) {
    if (Test-Path (Join-Path $Repo "core-i18n-pt\tools\core-env.ps1")) {
      & (Join-Path $Repo "core-i18n-pt\tools\core-env.ps1") remove $e.Name
    }
  }
}
function Do-Open {
  $g = Join-Path $Repo "tools\run-gui.ps1"
  if (Test-Path $g) { & $g } else { Say "[i] Repo ausente - escolha a opcao 1 (instalacao limpa) primeiro." }
}
function Do-AutoSyncTask {
  $t = Join-Path $Repo "tools\install-autosync-task.ps1"
  if (-not (Test-Path $t)) { Say "[X] script nao encontrado no repo - atualize o repo antes (opcao 3)."; return }
  Say ""
  Say "[Auto-update agendado]"
  Say "Cria a tarefa 'DeepSeek Harness AutoSync' no Agendador de Tarefas, que"
  Say "roda o auto-sync a cada 30 min apos o logon (respeita o flag do badge)."
  Say "Sem ela, o Windows nao atualiza sozinho e a versao congela."
  $w = Ask "(i)nstalar  |  (r)emover  |  (s)tatus  |  Enter p/ voltar:"
  if ($w -eq "i") { & $t }
  elseif ($w -eq "r") { & $t -Remove }
  elseif ($w -eq "s") { & $t -Status }
}


function Do-CleanKeep {
  Say ""
  Say "[MODO: limpa MANTENDO chaves/configuracoes]"
  Say "Vai apagar: repo, core global, instancias, atalhos e o que NAO for chave/config."
  Say "Vai PRESERVAR e reimportar no sistema novo:"
  Say "  - .credentials.yaml  (chaves de API)"
  Say "  - settings.yaml      (suas configuracoes)"
  Say "  - pastas llm-*       (configs de provedores/roteador)"
  Say "  - editor-assets / .agent-presets / .anonymous-user-id"
  Say "  - freeapi.db         (chaves do FreeLLMAPI, se existir)"
  if (-not (Test-Path $HomeCfg)) { Say "[i] Nao ha config atual - sera instalacao limpa simples."; Do-CleanInstall; return }
  $c = Ask "Digite 'limpar' para confirmar (Enter cancela):"
  if ($c -ne "limpar") { Say "Cancelado."; return }
  $bak = Join-Path $env:USERPROFILE (".dsh-keep-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
  New-Item -ItemType Directory -Force -Path $bak | Out-Null
  $keep = @(".credentials.yaml", "settings.yaml", ".anonymous-user-id", "editor-assets", ".agent-presets", "freeapi.db")
  foreach ($k in $keep) {
    $src = Join-Path $HomeCfg $k
    if (Test-Path $src) { Copy-Item -Recurse -Force $src $bak }
  }
  Get-ChildItem -Path $HomeCfg -Filter "llm-*" -ErrorAction SilentlyContinue | ForEach-Object {
    Copy-Item -Recurse -Force $_.FullName (Join-Path $bak $_.Name)
  }
  Say "Backup preservado em: $bak"
  Run-Remote "clean-windows.ps1"
  Run-Remote "install-windows.ps1"
  Say "Reimportando chaves/configuracoes..."
  if (-not (Test-Path $HomeCfg)) { New-Item -ItemType Directory -Force -Path $HomeCfg | Out-Null }
  Get-ChildItem -Force $bak | ForEach-Object { Copy-Item -Recurse -Force $_.FullName (Join-Path $HomeCfg $_.Name) }
  Say "[OK] Sistema limpo instalado COM suas chaves/configs (backup em $bak)."
}
# -------- modos nao-interativos --------
switch ($Mode) {
  "-Doctor"        { Show-State (Detect); exit 0 }
  "-ListInstances" { Show-Instances; exit 0 }
  "-RemoveAllInstances" { Do-RemoveAll; exit 0 }
  "-Clean"         { Do-CleanInstall; exit 0 }
  "-CleanKeep"     { Do-CleanKeep; exit 0 }
  "-Update"        { Do-Update; exit 0 }
  "-Open"          { Do-Open; exit 0 }
}

# -------- modo interativo --------
Say "== DeepSeek Harness - Instalador Interativo (Windows) =="
$state = Detect
Show-State $state

while ($true) {
  Say ""
  Say "O que voce quer fazer?"
  Say "  1) Instalacao LIMPA total (apaga TUDO e instala novo, sem nada)"
  Say "  2) Instalacao LIMPA MANTENDO chaves/configuracoes (importa p/ novo)"
  if ($state.repo -or $state.core -or $state.cfg) { Say "  3) Atualizar/completar instalacao existente (nao apaga nada)" }
  if ($state.instances.Count -gt 0) { Say "  4) Gerenciar instancias (listar / desinstalar)" }
  Say "  5) Abrir a GUI (sobe servidor + FreeLLMAPI se preciso)"
  Say "  6) Auto-update agendado (instalar/remover tarefa no Agendador)"
  Say "  0) Sair"
  $opt = Ask "Escolha:"
  $done = $false
  switch ($opt) {
    "1" { Do-CleanInstall; $state = Detect; $done = $true }
    "2" { Do-CleanKeep; $state = Detect; $done = $true }
    "3" { if ($state.repo -or $state.core -or $state.cfg) { Do-Update; $state = Detect; $done = $true } else { Say "Nada para atualizar." } }
    "4" {
      if ($state.instances.Count -gt 0) {
        Show-Instances
        $w = Ask "(r)emover uma  |  (t)odas  |  Enter p/ voltar:"
        if ($w -eq "r") { Remove-OneInstance } elseif ($w -eq "t") { Do-RemoveAll }
        $state = Detect
      } else { Say "Nenhuma instancia." }
    }
    "5" { Do-Open }
    "6" { Do-AutoSyncTask }
    "0" { Say "Tchau!"; break }
    default { Say "Opcao invalida." }
  }
  if ($done) { Say ""; Say "[OK] Concluido - saindo do instalador. Para outras acoes, rode de novo."; break }
}
