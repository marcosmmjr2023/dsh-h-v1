@echo off
REM ═══════════════════════════════════════════════════════════
REM  start-dsh-gui.bat — launcher da GUI (Windows)
REM  1) Sincroniza VIA DE MÃO DUPLA (auto-sync: recebe + publica)
REM  2) Sobe a GUI do core global (@deepseek-ai/dsh)
REM ═══════════════════════════════════════════════════════════
title DeepSeek Harness Web GUI (dsh-h-v1)
cd /d "%~dp0"

echo [1/2] Sincronizando com o GitHub (auto-sync: recebe + publica)...
if exist "%~dp0tools\auto-sync.ps1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0tools\auto-sync.ps1"
) else if exist "%~dp0tools\sync-pull.ps1" (
    powershell -ExecutionPolicy Bypass -File "%~dp0tools\sync-pull.ps1"
) else (
    echo [!] tools\auto-sync.ps1 nao encontrado — pulando sync.
)

echo [2/2] Iniciando DeepSeek Harness GUI (porta 3081)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run-gui.ps1"
pause
