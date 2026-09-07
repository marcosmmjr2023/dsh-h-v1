# install-windows.ps1 — Instalador do DeepSeek Harness + sistema dsh (Windows)
# Uso (uma linha, do repositório público):
#   irm https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/install-windows.ps1 | iex
# Opções: -NoDshAlias (não instala o comando 'dsh' no perfil)
[CmdletBinding()]
param([switch]$NoDshAlias)
$ErrorActionPreference = "Stop"

Write-Host "== Instalador DeepSeek Harness (dsh) =="
# 1) Pré-requisitos
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
Write-Host "node: $(& node -v)  | npm: $(& npm -v)"

# 2) Clone/update do repo
$Repo = Join-Path $env:USERPROFILE "projects\dsh\dsh-h-v1"
if (-not (Test-Path (Join-Path $Repo ".git"))) {
  New-Item -ItemType Directory -Force -Path (Split-Path $Repo -Parent) | Out-Null
  git clone https://github.com/marcosmmjr2023/dsh-h-v1.git $Repo
} else {
  git -C $Repo pull --ff-only
}
Set-Location $Repo

# 3) Core global na versão pinada (se ainda não estiver)
$pinned = (Get-Content manifest.json -Raw | ConvertFrom-Json).core.pinned
$inst = (& npm ls -g "@deepseek-ai/dsh" --depth=0 2>$null) -join ""
if ($inst -notmatch [regex]::Escape($pinned)) {
  Write-Host "Instalando core pinado: $pinned"
  & npm install -g "@deepseek-ai/dsh@$pinned"
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
    Write-Host "✔ comando 'dsh' adicionado ao perfil (reabra o PowerShell)."
  }
}

Write-Host ""
Write-Host "== Pronto! =="
Write-Host "  1) Abra a GUI:  dsh up   (ou:  .\start-dsh-gui.bat)"
Write-Host "  2) No chip do core: ➕ Criar instancia com core novo (progresso incluso)"
Write-Host "  3) Desinstalar: dentro da instancia, menu lateral -> 🗑 Desinstalar"
Write-Host "  4) Atualizar depois:  dsh update"
Write-Host "  5) Diagnosticar:      dsh doctor"
Write-Host ""
Write-Host "Se der erro, cole a saida aqui no repo (projeto dsh-h-v1)."
