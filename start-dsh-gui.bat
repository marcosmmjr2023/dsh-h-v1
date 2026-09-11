@echo off
REM ===========================================================
REM  start-dsh-gui.bat - launcher da GUI (Windows)
REM  1) Sincroniza VIA DE MAO DUPLA (auto-sync: recebe + publica)
REM  2) Sobe a GUI do core global (@deepseek-ai/dsh)
REM ===========================================================
title DeepSeek Harness Web GUI (dsh-h-v1)
cd /d "%~dp0"

REM Host do PowerShell: usa o que existir na maquina - pwsh (7+) tem preferencia,
REM senao o Windows PowerShell (5.1, que acompanha o Windows). Nenhuma versao e
REM exigida: os scripts do repo rodam igual nos dois. Caminhos absolutos primeiro
REM (funciona mesmo com PATH restrita) e depois a busca no PATH.
set "PSEXE="
for %%P in (
  "%ProgramFiles%\PowerShell\7\pwsh.exe"
  "%LOCALAPPDATA%\Microsoft\WindowsApps\pwsh.exe"
  "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
) do if not defined PSEXE if exist "%%~P" set "PSEXE=%%~P"
if not defined PSEXE ( where pwsh >nul 2>nul && set "PSEXE=pwsh" )
if not defined PSEXE ( where powershell >nul 2>nul && set "PSEXE=powershell" )
if not defined PSEXE (
  echo [X] PowerShell nao encontrado ^(nem pwsh, nem powershell.exe^) - instale o Windows PowerShell.
  pause
  exit /b 1
)

echo [1/2] Sincronizando com o GitHub (auto-sync: recebe + publica)...
if exist "%~dp0tools\auto-sync.ps1" (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\auto-sync.ps1"
) else if exist "%~dp0tools\sync-pull.ps1" (
    "%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\sync-pull.ps1"
) else (
    echo [!] tools\auto-sync.ps1 nao encontrado - pulando sync.
)

echo [2/2] Iniciando DeepSeek Harness GUI (porta 3081)...
"%PSEXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run-gui.ps1"
pause
