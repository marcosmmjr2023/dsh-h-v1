@echo off
REM ═══════════════════════════════════════════════════════════
REM  start-dsh-gui.bat — launcher da GUI (Windows)
REM  1) Recebe atualizações do overlay (sync-pull)
REM  2) Sobe a GUI do core global (@deepseek-ai/dsh)
REM ═══════════════════════════════════════════════════════════
title DeepSeek Harness Web GUI (dsh-h-v1)
cd /d "%~dp0"

echo [1/2] Sincronizando overlay com o repo (sync-pull)...
if exist "%~dp0tools\sync-pull.ps1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0tools\sync-pull.ps1"
) else (
    echo [!] tools\sync-pull.ps1 nao encontrado — pulando sync.
)

echo [2/2] Iniciando DeepSeek Harness GUI na porta 3080...
where dsh >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Comando 'dsh' nao encontrado no PATH.
    echo     Instale o core:  npm install -g @deepseek-ai/dsh
    pause
    exit /b 1
)
dsh web --port 3080
pause
