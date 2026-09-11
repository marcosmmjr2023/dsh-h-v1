# install-windows.ps1 - Instalador do DeepSeek Harness + sistema dsh (Windows)
# Uso (uma linha, do repositorio publico):
#   powershell -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/install-windows.ps1 | iex"
# Opcoes: -NoDshAlias (nao instala o comando 'dsh' no perfil)
[CmdletBinding()]
param([switch]$NoDshAlias,[switch]$NoGui)
. (Join-Path (Split-Path -Parent $PSScriptRoot) "tools\ps-text.ps1")
$ErrorActionPreference = "Stop"

Write-Host "== Instalador DeepSeek Harness (dsh) =="
$LogFile = Join-Path $env:USERPROFILE ".dsh-install.log"
# Transcricao e opcional: em algumas sessoes (ex.: powershell -Command via iex)
# o host bloqueia Start-Transcript - o install NAO pode morrer por causa do log.
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

# 1b) Politica de execucao: sem isso, 'dsh' cai no shim do core e .ps1 bloqueia.
# So afeta o usuario atual (sem admin); pergunta uma vez.
try {
  $pol = Get-ExecutionPolicy -Scope CurrentUser
  if ($pol -notin @("RemoteSigned","Unrestricted","Bypass")) {
    $ans = Read-Host "Liberar scripts locais p/ seu usuario (RemoteSigned)? [S/n]"
    if ($ans -eq "" -or $ans -match "^[SsYy]") {
      Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
      Write-Host "[OK] politica CurrentUser: RemoteSigned (vale p/ novos shells)"
    } else { Write-Host "[i] mantido $pol - use Bypass quando precisar" }
  }
} catch { Write-Host ("[i] nao ajustei a politica: " + $_.Exception.Message) }

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
# npm 11+ bloqueia install scripts por padrao: sem eles, koffi/node-pty nao
# instalam o binario nativo e o boot morre (Mismatched native Koffi modules).
$allowList = "@deepseek-ai/dsh-subprocess-local,koffi,node-pty,@google/genai,protobufjs"
$npmMajor = 0
try { $npmMajor = [int]((& npm.cmd -v 2>$null).Trim().Split(".")[0]) } catch { }
$allowFlags = @()
if ($npmMajor -ge 11) {
  $allowFlags = @("--allow-scripts=$allowList")
  try {
    $cur = (& npm.cmd config get allow-scripts --location=user 2>$null).Trim()
    if ($cur -notmatch "koffi") {
      & npm.cmd config set allow-scripts=$allowList --location=user | Out-Null
      Write-Host "[OK] npm allow-scripts configurado (koffi/node-pty)"
    }
  } catch { }
}
if ($inst -notmatch [regex]::Escape($pinned)) {
  Write-Host "Instalando core pinado: $pinned"
  & npm.cmd install -g "@deepseek-ai/dsh@$pinned" @allowFlags
} else {
  Write-Host "core ja instalado: $pinned"
}
# 3b) Valida o koffi de verdade (carrega o binding nativo). Se falhar,
# reinstala com --force para rodar os install scripts que foram bloqueados.
function Test-Koffi([string]$npmRoot) {
  $koffi = Join-Path $npmRoot "@deepseek-ai\dsh\node_modules\koffi"
  if (-not (Test-Path (Join-Path $koffi "package.json"))) { $koffi = Join-Path $npmRoot "koffi" }
  if (-not (Test-Path (Join-Path $koffi "package.json"))) { return $false }
  $env:NODE_PATH = (Join-Path $npmRoot "@deepseek-ai\dsh\node_modules")
  & node -e "require('koffi')" 2>$null
  return ($LASTEXITCODE -eq 0)
}
$npmRoot = (& npm.cmd root -g).Trim()
if (Test-Koffi $npmRoot) { Write-Host "[OK] koffi validado (nativo carrega)" }
else {
  Write-Host "[X] koffi quebrado - reinstalando o core com --force..."
  & npm.cmd install -g --force "@deepseek-ai/dsh@$pinned" @allowFlags
  if (Test-Koffi $npmRoot) { Write-Host "[OK] core reinstalado, koffi validado" }
  else { Write-Host "[X] koffi ainda falha - confira o Node (22 LTS recomendado) e o antivirus" }
}

# 4) pt-BR (pt-ride)
& (Join-Path $Repo "core-i18n-pt\tools\apply-pt-core.ps1") -Cmd --force
if ($LASTEXITCODE -ne 0) {
  Write-Host "[AVISO] pt-BR nao foi aplicado agora - o sistema funciona em ingles." -ForegroundColor Yellow
  Write-Host "        Reaplique depois com: dsh pt   (ou core-i18n-pt\tools\apply-pt-core.ps1 -Cmd --force)"
}

# 5) Comando 'dsh' no perfil do PowerShell (se permitido)
if (-not $NoDshAlias) {
  $profileDir = Split-Path $PROFILE -Parent
  if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Force -Path $profileDir | Out-Null }
  $lines = @(
    "function dsh { & `"$Repo\tools\dsh-cli.ps1`" @args }"
  )
  $has = if (Test-Path $PROFILE) { Get-Content -Encoding UTF8 $PROFILE -Raw -ErrorAction SilentlyContinue } else { "" }
  if ($has -notmatch "function dsh") {
    $lines | Out-Utf8NoBom -Path $PROFILE -Append
    Write-Host "[OK] comando 'dsh' adicionado ao perfil (reabra o PowerShell)."
  }
  Write-Host "[i] 'dsh' na sessao atual ainda pode cair no shim do core (npm). Use um NOVO PowerShell,"
  Write-Host "    ou rode direto: powershell -ExecutionPolicy Bypass -File `"$Repo\tools\dsh-cli.ps1`" <acao>"
}

# 6) FreeLLMAPI (gateway local 3002 + admin) - integrado
Write-Host "Preparando FreeLLMAPI local..."
try { & (Join-Path $Repo "tools\flm-setup.ps1") } catch { Write-Host "[i] FreeLLMAPI nao subiu: $($_.Exception.Message) (rode depois: dsh flm-setup)" }

# 7) Atalhos Desktop + Menu Iniciar
try {
    $ws = New-Object -ComObject WScript.Shell
    $ico = Join-Path $Repo "assets\deepseek.ico"
    if (-not (Test-Path $ico)) { $ico = "" }
    # atalho aponta para o MESMO host que esta rodando (5.1 ou 7+)
    $psHostHelper = Join-Path $Repo "tools\ps-host.ps1"
    if (Test-Path $psHostHelper) { . $psHostHelper }
    $tgt = if (Get-Command Get-PsHostPersistPath -ErrorAction SilentlyContinue) { Get-PsHostPersistPath } else { $null }
    if (-not $tgt) { $tgt = "powershell.exe" }
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
