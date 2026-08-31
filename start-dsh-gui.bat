@echo off
title DeepSeek Harness Web GUI
echo Iniciando DeepSeek Harness GUI na porta 3080...
cd /d "%~dp0source"
node lib/bin.js web --port 3080
pause
