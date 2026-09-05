# dsh-h-v1 - Instalador Windows (PowerShell)
# Instala o core (@deepseek-ai/dsh via npm) e aplica o overlay em
# %USERPROFILE%\.dsh via sync-pull.ps1. Cria atalho na Area de Trabalho.
# Requisitos: PowerShell 5.1+, Node.js 20+, Git

param(
    [switch]$SkipCoreInstall
)

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  DSH-H-V1 - INSTALADOR WINDOWS (overlay + core via npm)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

function Test-CommandExists([string]$command) {
    try { $null = Get-Command $command -ErrorAction Stop; return $true } catch { return $false }
}

# 1. Node.js
Write-Host "[1/4] Verificando Node.js..." -ForegroundColor Yellow
if (-not (Test-CommandExists "node")) {
    Write-Host "[X] Node.js nao encontrado! Instale o v20+ LTS de https://nodejs.org/ e rode de novo." -ForegroundColor Red
    Read-Host "Pressione Enter para sair..."; exit 1
}
Write-Host "[OK] Node.js $(node -v)" -ForegroundColor Green

# 2. Git
Write-Host "[2/4] Verificando Git..." -ForegroundColor Yellow
if (-not (Test-CommandExists "git")) {
    Write-Host "[X] Git nao encontrado! Instale o Git for Windows." -ForegroundColor Red
    Read-Host "Pressione Enter para sair..."; exit 1
}
Write-Host "[OK] Git encontrado." -ForegroundColor Green

# 3. Core (L1)
Write-Host "[3/4] Instalando core @deepseek-ai/dsh..." -ForegroundColor Yellow
if (-not $SkipCoreInstall) {
    try {
        npm install -g @deepseek-ai/dsh
        Write-Host "[OK] Core instalado." -ForegroundColor Green
    } catch {
        Write-Host "[X] Erro ao instalar o core: $_" -ForegroundColor Red
        Read-Host "Pressione Enter para sair..."; exit 1
    }
} else {
    Write-Host "[*] Pulando instalacao do core (-SkipCoreInstall)." -ForegroundColor Yellow
}

# 4. Overlay (L2) + atalho
Write-Host "[4/4] Aplicando overlay em %USERPROFILE%\.dsh..." -ForegroundColor Yellow
$repoRoot = Split-Path -Parent $PSScriptRoot   # installer/ -> raiz do clone
$syncPull  = Join-Path $repoRoot "tools\sync-pull.ps1"
if (Test-Path $syncPull) {
    & powershell -ExecutionPolicy Bypass -File $syncPull
} else {
    Write-Host "[!] tools\sync-pull.ps1 nao encontrado em $repoRoot" -ForegroundColor Yellow
}

$desktop = [Environment]::GetFolderPath("Desktop")
$shortcut = Join-Path $desktop "dsh-h-v1.bat"
@("@echo off", "cd /d `"$repoRoot`"", "call start-dsh-gui.bat") | Out-File -FilePath $shortcut -Encoding ASCII -Force
Write-Host "[OK] Atalho criado: $shortcut" -ForegroundColor Green

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  INSTALACAO CONCLUIDA!" -ForegroundColor Cyan
Write-Host "  Inicie com:  dsh-h-v1.bat (Area de Trabalho)" -ForegroundColor White
Write-Host "  GUI em: http://127.0.0.1:3080" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan
Read-Host "Pressione Enter para sair..."
