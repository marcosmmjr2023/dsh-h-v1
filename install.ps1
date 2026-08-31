# DeepSeek Harness GUI - Instalador Completo para Windows (PowerShell)
# Versao: 1.0
# Requisitos: PowerShell 5.1+

param(
    [switch]$SkipNodeCheck,
    [switch]$SkipPnpmInstall,
    [switch]$SkipDepsInstall
)

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  DEEPSEEK HARNESS GUI - INSTALADOR PARA WINDOWS (v1)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# Funcao para verificar se um comando existe
function Test-CommandExists([string]$command) {
    try {
        $null = Get-Command $command -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Funcao para verificar versao do Node.js
function Get-NodeVersion {
    try {
        $version = node -v
        return $version.Trim()
    } catch {
        return $null
    }
}

# 1. Verificar Node.js
Write-Host "[1/5] Verificando Node.js..." -ForegroundColor Yellow
if (-not $SkipNodeCheck) {
    if (-not (Test-CommandExists "node")) {
        Write-Host "[X] Node.js nao encontrado!" -ForegroundColor Red
        Write-Host "Por favor, instale o Node.js v20+ LTS de https://nodejs.org/ e reinicie este instalador." -ForegroundColor Yellow
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
    
    $nodeVersion = Get-NodeVersion
    if (-not $nodeVersion) {
        Write-Host "[X] Nao foi possivel obter a versao do Node.js!" -ForegroundColor Red
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
    
    Write-Host "[OK] Node.js encontrado (Versao: $nodeVersion)" -ForegroundColor Green
}

# 2. Verificar pnpm ou npm
Write-Host "[2/5] Verificando gerenciador de pacotes (pnpm / npm)..." -ForegroundColor Yellow
$pkgManager = $null

if (Test-CommandExists "pnpm") {
    $pkgManager = "pnpm"
    Write-Host "[OK] pnpm encontrado." -ForegroundColor Green
} else {
    Write-Host "[*] pnpm nao encontrado globalmente. Tentando instalar pnpm via npm..." -ForegroundColor Yellow
    
    if (-not (Test-CommandExists "npm")) {
        Write-Host "[X] NPM tambem nao encontrado! Instale o Node.js completo." -ForegroundColor Red
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
    
    if (-not $SkipPnpmInstall) {
        try {
            Write-Host "Instalando pnpm globalmente..." -ForegroundColor Yellow
            npm install -g pnpm
            if (Test-CommandExists "pnpm") {
                $pkgManager = "pnpm"
                Write-Host "[OK] pnpm instalado com sucesso." -ForegroundColor Green
            } else {
                Write-Host "[!] Falha ao instalar pnpm globalmente. Usaremos npm padrao." -ForegroundColor Yellow
                $pkgManager = "npm"
            }
        } catch {
            Write-Host "[!] Erro ao instalar pnpm: $_" -ForegroundColor Yellow
            $pkgManager = "npm"
        }
    } else {
        $pkgManager = "npm"
    }
}

# 3. Configurar ambiente e plugins
Write-Host "[3/5] Configurando ambiente e plugins locais..." -ForegroundColor Yellow
$dshConfigDir = Join-Path $env:USERPROFILE ".dsh"
if (-not (Test-Path $dshConfigDir)) {
    New-Item -ItemType Directory -Path $dshConfigDir -Force | Out-Null
}

$sourceConfigDir = Join-Path $PSScriptRoot "dsh_dot_dsh_config"
if (Test-Path $sourceConfigDir) {
    try {
        Copy-Item -Path "$sourceConfigDir\*" -Destination $dshConfigDir -Recurse -Force
        Write-Host "[OK] Configuracoes e plugins copiados com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "[!] Erro ao copiar configuracoes: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[!] Pasta dsh_dot_dsh_config nao encontrada no pacote. Pulando..." -ForegroundColor Yellow
}

# 4. Instalar dependencias do projeto
Write-Host "[4/5] Instalando dependencias do DeepSeek Harness..." -ForegroundColor Yellow
$sourceDir = Join-Path $PSScriptRoot "source"

if (-not (Test-Path $sourceDir)) {
    Write-Host "[X] Pasta 'source' nao encontrada!" -ForegroundColor Red
    Read-Host "Pressione Enter para sair..."
    exit 1
}

Set-Location $sourceDir

if (-not $SkipDepsInstall) {
    try {
        if ($pkgManager -eq "pnpm") {
            Write-Host "Usando pnpm para instalar dependencias..." -ForegroundColor Yellow
            pnpm install
        } else {
            Write-Host "Usando npm para instalar dependencias..." -ForegroundColor Yellow
            npm install
        }
        Write-Host "[OK] Dependencias instaladas com sucesso." -ForegroundColor Green
    } catch {
        Write-Host "[X] Erro ao instalar dependencias: $_" -ForegroundColor Red
        Read-Host "Pressione Enter para sair..."
        exit 1
    }
} else {
    Write-Host "[*] Pulando instalacao de dependencias (--SkipDepsInstall)." -ForegroundColor Yellow
}

# 5. Criar script de inicializacao
Write-Host "[5/5] Criando script de inicializacao..." -ForegroundColor Yellow
$startScriptPath = Join-Path $PSScriptRoot "start-dsh-gui.bat"
$startScriptContent = @"
@echo off
title DeepSeek Harness Web GUI
echo Iniciando DeepSeek Harness GUI na porta 3080...
cd /d "%~dp0source"
node lib/bin.js web --port 3080
pause
"@

try {
    $startScriptContent | Out-File -FilePath $startScriptPath -Encoding ASCII -Force
    Write-Host "[OK] Script de inicializacao criado com sucesso." -ForegroundColor Green
} catch {
    Write-Host "[!] Erro ao criar script de inicializacao: $_" -ForegroundColor Yellow
}

Write-Host "" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "  INSTALACAO CONCLUIDA COM SUCESSO!" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "Para iniciar a GUI do DeepSeek Harness, execute o arquivo:" -ForegroundColor White
Write-Host "  start-dsh-gui.bat" -ForegroundColor Yellow
Write-Host "Ou acesse apos iniciar: http://127.0.0.1:3080" -ForegroundColor White
Write-Host "========================================================" -ForegroundColor Cyan

Read-Host "Pressione Enter para sair..."
