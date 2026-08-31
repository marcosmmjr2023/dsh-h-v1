@echo off
setlocal
title DeepSeek Harness dsh-h-v1
rem Lanca a instancia paralela como um PROGRAMA independente:
rem servidor sobe (se preciso) e a GUI abre em janela de app do Chrome,
rem sem abas nem barra de endereco - igual a versao principal.
set "CHROME=C:\Program Files\Google\Chrome\Application\chrome.exe"
if not exist "%CHROME%" goto fallback

rem Se o servidor nao estiver no ar, inicia-o minimizado em background.
curl -s -o nul -w "%%{http_code}" http://127.0.0.1:3090 > "%TEMP%\dsh-h-v1-port.txt" 2>nul
set /p PORT_CODE=<"%TEMP%\dsh-h-v1-port.txt"
if "%PORT_CODE%"=="200" goto open
echo Iniciando o servidor DeepSeek Harness dsh-h-v1...
start "DeepSeek Harness dsh-h-v1 servidor" /min cmd /c ""%~dp0start-parallel-dsh.bat""

rem Aguarda o servidor responder na porta 3090 (ate ~90 segundos).
set /a TRIES=0
:waitloop
set /a TRIES+=1
if %TRIES% gtr 90 goto open
curl -s -o nul -w "%%{http_code}" http://127.0.0.1:3090 > "%TEMP%\dsh-h-v1-port2.txt" 2>nul
set /p PORT2=<"%TEMP%\dsh-h-v1-port2.txt"
if "%PORT2%"=="200" goto open
timeout /t 1 /nobreak > nul
goto waitloop

:open
echo Abrindo DeepSeek Harness dsh-h-v1 em janela de app...
start "" "%CHROME%" --app="http://127.0.0.1:3090"
exit /b 0

:fallback
echo Chrome nao encontrado; abrindo no navegador padrao...
start "" "http://127.0.0.1:3090"
exit /b 0
