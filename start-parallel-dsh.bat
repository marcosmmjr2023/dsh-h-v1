@echo off
setlocal
title DeepSeek Harness dsh-h-v1 servidor
rem Instancia paralela do bundle dsh-h-v1: usa o proprio config (DSH_HOME)
rem apontando para dsh_dot_dsh_config, sem tocar no .dsh da instalacao atual.
set "DSH_HOME=%~dp0dsh_dot_dsh_config"
rem LAYOUT_PANEL_DIRS: diretorios monitorados pelo painel lateral (lista ;).
rem Inclui o workspace da sessao E a pasta projects (onde ficam os repositorios).
if not defined LAYOUT_PANEL_DIRS set "LAYOUT_PANEL_DIRS=%USERPROFILE%\OneDrive\Documentos\projetos;%USERPROFILE%\projects"
rem DSH_CLI_LIB: onde os plugins (smart-router, openrouter-enhanced, model-visibility)
rem procuram schemastery/dsh-settings/dsh-llm-pi-ai (aponta para o lib/ do source).
set "DSH_CLI_LIB=%~dp0source\lib"
echo Iniciando DeepSeek Harness dsh-h-v1 na porta 3090...
echo DSH_HOME=%DSH_HOME%
cd /d "%~dp0source"
node --require "%~dp0preload.cjs" lib/bin.js web --port 3090 --no-open
pause
