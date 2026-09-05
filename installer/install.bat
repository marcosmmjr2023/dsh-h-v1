@echo off
setlocal EnableDelayedExpansion
title dsh-h-v1 - Instalador Windows (git + npm)
REM ═══════════════════════════════════════════════════════════
REM  install.bat — instala a camada personalizada (overlay) + core
REM  Pré-requisito: este repo clonado (git clone ... dsh-h-v1)
REM ═══════════════════════════════════════════════════════════
echo ========================================================
echo   DSH-H-V1 - INSTALADOR WINDOWS (overlay + core via npm)
echo ========================================================
echo.

REM 1. Node.js
echo [1/4] Verificando Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Node.js nao encontrado! Instale o v20+ LTS de https://nodejs.org/ e rode de novo.
    pause
    exit /b 1
)
for /f "delims=" %%i in ('node -v') do set NODE_VER=%%i
echo [OK] Node.js %NODE_VER%

REM 2. Git
echo [2/4] Verificando Git...
where git >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Git nao encontrado! Instale o Git for Windows e rode de novo.
    pause
    exit /b 1
)
echo [OK] Git encontrado.

REM 3. Core do harness (L1) — canal oficial npm
echo [3/4] Instalando core @deepseek-ai/dsh (npm install -g)...
call npm install -g @deepseek-ai/dsh
if %errorlevel% neq 0 (
    echo [X] Erro ao instalar o core. Verifique sua conexao/npm.
    pause
    exit /b 1
)
echo [OK] Core instalado.

REM 4. Overlay (L2) — aplica em %USERPROFILE%\.dsh e cria atalho na area de trabalho
echo [4/4] Aplicando overlay em %%USERPROFILE%%\\.dsh e criando atalho...
powershell -ExecutionPolicy Bypass -File "%~dp0..\tools\sync-pull.ps1"
if %errorlevel% neq 0 (
    echo [!] sync-pull retornou erro — revise acima.
)

REM Atalho: wrapper na Area de Trabalho apontando para o launcher do repo
set "REPO=%~dp0.."
(
echo @echo off
echo cd /d "%REPO%"
echo call start-dsh-gui.bat
) > "%USERPROFILE%\Desktop\dsh-h-v1.bat"
echo [OK] Atalho criado: Area de Trabalho\dsh-h-v1.bat

echo.
echo ========================================================
echo   INSTALACAO CONCLUIDA!
echo   Inicie com:  Area de Trabalho\dsh-h-v1.bat
echo   (ou rode start-dsh-gui.bat na raiz do clone)
echo   GUI em: http://127.0.0.1:3080
echo ========================================================
pause
