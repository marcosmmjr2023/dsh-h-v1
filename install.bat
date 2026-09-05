@echo off
setlocal EnableDelayedExpansion
title DeepSeek Harness GUI - Instalador Completo para Windows

echo ========================================================
echo   DEEPSEEK HARNESS GUI - INSTALADOR PARA WINDOWS (v1)
echo ========================================================
echo.

REM 1. Verificar se Node.js esta instalado
echo [1/5] Verificando Node.js...
where node >nul 2>&1
if %errorlevel% neq 0 (
    echo [X] Node.js nao encontrado!
    echo Por favor, instale o Node.js v20+ LTS de https://nodejs.org/ e reinicie este instalador.
    pause
    exit /b 1
)
for /f "tokens=v" %%i in ('node -v') do set NODE_VER=%%i
echo [OK] Node.js encontrado (Versao: %NODE_VER%)

REM 2. Verificar se pnpm ou npm esta disponivel
echo [2/5] Verificando gerenciador de pacotes (pnpm / npm)...
where pnpm >nul 2>&1
if %errorlevel% eq 0 (
    set PKG_MANAGER=pnpm
    echo [OK] pnpm encontrado.
) else (
    echo [*] pnpm nao encontrado globalmente. Tentando instalar pnpm via npm...
    where npm >nul 2>&1
    if %errorlevel% neq 0 (
        echo [X] NPM tambem nao encontrado! Instale o Node.js completo.
        pause
        exit /b 1
    )
    call npm install -g pnpm
    if %errorlevel% neq 0 (
        echo [*] Falha ao instalar pnpm globalmente. Usaremos npm padrao.
        set PKG_MANAGER=npm
    ) else (
        set PKG_MANAGER=pnpm
        echo [OK] pnpm instalado com sucesso.
    )
)

REM 3. Copiar configuracoes do usuario para %USERPROFILE%\.dsh
echo [3/5] Configurando ambiente e plugins locais em %%USERPROFILE%%\\.dsh...
if not exist "%USERPROFILE%\.dsh" mkdir "%USERPROFILE%\.dsh"

if exist "%~dp0dsh_dot_dsh_config" (
    xcopy /E /I /Y "%~dp0dsh_dot_dsh_config" "%USERPROFILE%\.dsh" >nul
    echo [OK] Configuracoes e plugins copiados com sucesso.
) else (
    echo [!] Pasta dsh_dot_dsh_config nao encontrada no pacote. Pulando...
)

REM 4. Instalar dependencias do projeto
echo [4/5] Instalando dependencias do DeepSeek Harness...
cd /d "%~dp0source"
if "%PKG_MANAGER%"=="pnpm" (
    pnpm install
) else (
    npm install
)
if %errorlevel% neq 0 (
    echo [X] Erro ao instalar dependencias!
    pause
    exit /b 1
)
echo [OK] Dependencias instaladas com sucesso.

REM 5. Criar Atalho / Script de Execucao para o Windows
echo [5/5] Criando script de inicializacao (start-dsh-gui.bat)...
cd /d "%~dp0"
(
echo @echo off
echo title DeepSeek Harness Web GUI
echo echo Iniciando DeepSeek Harness GUI na porta 3080...
echo cd /d "%~dp0source"
echo node lib/bin.js web --port 3080
echo pause
) > start-dsh-gui.bat

echo.
echo ========================================================
echo   INSTALACAO CONCLUIDA COM SUCESSO!
echo ========================================================
echo Para iniciar a GUI do DeepSeek Harness, execute o arquivo:
echo   start-dsh-gui.bat
echo Ou acesse apos iniciar: http://127.0.0.1:3080
echo ========================================================
pause
