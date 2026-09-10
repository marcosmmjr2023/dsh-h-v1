# install-windows.ps1 - Instalador do DeepSeek Harness + sistema dsh (Windows)
# Uso (uma linha, do repositorio publico):
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/install-windows.ps1 | iex"
# Opcoes: -NoDshAlias (nao instala o comando 'dsh' no perfil)
[CmdletBinding()]
param([switch]$NoDshAlias,[switch]$NoGui)
$ErrorActionPreference = "Stop"

Write-Host "== Instalador DeepSeek Harness (dsh) =="
$LogFile = Join-Path $env:USERPROFILE ".dsh-install.log"
# Transcricao e opcional: em algumas sessoes (ex.: powershell -Command via iex)
# o host bloqueia Start-Transcript — o install NAO pode morrer por causa do log.
$script:TranscriptOn = $false
try { Start-Transcript -Path $LogFile -Force -ErrorAction Stop | Out-Null; $script:TranscriptOn = $true }
catch { Write-Host "[i] log em arquivo indisponivel nesta sessao; seguindo sem .dsh-install.log" }
# 1) Pre-requisitos
foreach ($cmd in @("node","npm","git")) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    Write-Host "Faltando: $cmd"
    try { & winget install --id OpenJS.NodeJS.LTS --accept-source-agreements --accept-package-agreements 2>$null | Out-Null
          & winget install --id Git.Git --accept-source-agreements --accept-package-agreements 2>$null | Out-Null }
    catch { }
  }
}
foreach ($cmd in @("node","npm","git")) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
    throw "Instale $cmd (Node.js LTS: nodejs.org e Git: git-scm.com) e reabra o PowerShell."
  }
}
Write-Host "node: $(& node -v)  | npm: $(& npm.cmd -v)"

# 2) Clone/update do repo
$Repo = Join-Path $env:USERPROFILE "projects\dsh\dsh-h-v1"
if (-not (Test-Path (Join-Path $Repo ".git"))) {
  New-Item -ItemType Directory -Force -Path (Split-Path $Repo -Parent) | Out-Null
  git clone https://github.com/marcosmmjr2023/dsh-h-v1.git $Repo
} else {
  git -C $Repo pull --ff-only
}
Set-Location $Repo

# 3) Core global na versao pinada (se ainda nao estiver)
$pinned = (Get-Content manifest.json -Raw | ConvertFrom-Json).core.pinned
$inst = (& npm.cmd ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
if ($inst -notmatch [regex]::Escape($pinned)) {
  Write-Host "Instalando core pinado: $pinned"
  & npm.cmd install -g "@deepseek-ai/dsh@$pinned"
} else {
  Write-Host "core ja instalado: $pinned"
}

# 4) pt-BR (pt-ride)
& .\core-i18n-pt\tools\apply-pt-core.ps1 --force

# 5) Comando 'dsh' no perfil do PowerShell (se permitido)
if (-not $NoDshAlias) {
  $profileDir = Split-Path $PROFILE -Parent
  if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
  $lines = @(
    "function dsh { & `"$Repo\tools\dsh-cli.ps1`" @args }"
  )
  $has = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue } else { "" }
  if ($has -notmatch "function dsh") {
    Add-Content -Encoding UTF8 $PROFILE $lines
    Write-Host "[OK] comando 'dsh' adicionado ao perfil (reabra o PowerShell)."
  }
}

# 6) FreeLLMAPI (gateway local 3002 + admin) - integrado
Write-Host "Preparando FreeLLMAPI local..."
try { & (Join-Path $Repo "tools\flm-setup.ps1") } catch { Write-Host "[i] FreeLLMAPI nao subiu: $($_.Exception.Message) (rode depois: dsh flm-setup)" }

# 7) Atalhos Desktop + Menu Iniciar
try {
    $ws = New-Object -ComObject WScript.Shell
    $ico = Join-Path $Repo "assets\deepseek.ico"
    if (-not (Test-Path $ico)) { $ico = "" }
    $tgt = "powershell.exe"
    $a = "-NoProfile -ExecutionPolicy Bypass -File `"" + (Join-Path $Repo "tools\run-gui.ps1") + "`""
    $desk = Join-Path ([Environment]::GetFolderPath("Desktop")) "DeepSeek Harness.lnk"
    $sm = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\DeepSeek Harness.lnk"
    foreach ($lp in @($desk, $sm)) {
      $lnk = $ws.CreateShortcut($lp)
      $lnk.TargetPath = $tgt
      $lnk.Arguments = $a
      $lnk.WorkingDirectory = $Repo
      $lnk.Description = "DeepSeek Harness (dsh-h-v1)"
      if ($ico) { $lnk.IconLocation = "$ico,0" }
      $lnk.Save()
      Write-Host "[OK] atalho com icone: $lp"
    }
  } catch { Write-Host "[i] nao foi possivel criar atalhos: $($_.Exception.Message)" }

# 7) Abre a GUI (automatico) e verifica o overlay
if (-not $NoGui) {
  Write-Host "Abrindo a GUI..."
  try { & (Join-Path $Repo "tools\run-gui.ps1") } catch { Write-Host "[i] GUI nao abriu automaticamente - rode: dsh up" }
  Start-Sleep -Seconds 8
  try {
    $html = (Invoke-WebRequest -UseBasicParsing -TimeoutSec 8 -Uri "http://127.0.0.1:3081/").Content
    if ($html -match "dsh-version-badge|dlp-body") { Write-Host "[OK] OVERLAY presente (menu lateral/badges)." }
    else { Write-Host "[X] OVERLAY ausente na GUI - veja logs abaixo e cole aqui." }
  } catch { Write-Host "[i] nao consegui verificar a pagina (talvez ainda subindo)" }
}
try { if ($script:TranscriptOn) { Stop-Transcript | Out-Null } } catch { }
if ($script:TranscriptOn) { Write-Host ""; Write-Host "Log completo: $LogFile" }

Write-Host ""
Write-Host "== Pronto! =="
Write-Host "  1) Abra a GUI:  dsh up   (ou atalho Desktop/Menu Iniciar)"
Write-Host "  2) No chip do core:  Criar instancia com core novo (progresso incluso)"
Write-Host "  3) Desinstalar: dentro da instancia, menu lateral -> [uninstall] Desinstalar"
Write-Host "  4) Atualizar depois:  dsh update"
Write-Host "  5) Diagnosticar:      dsh doctor"
Write-Host ""
Write-Host "Se der erro, cole a saida aqui no repo (projeto dsh-h-v1)."
