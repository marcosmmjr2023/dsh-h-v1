#!/usr/bin/env bash
# dsh-setup.sh — Instalador COMPLETO e INTERATIVO do DeepSeek Harness (Linux)
# (equivalente ao dsh-setup.ps1 do Windows)
# Detecta o estado da máquina, mostra o idioma e pergunta como instalar.
#
# 1 linha:  bash <(curl -fsSL https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer/dsh-setup.sh)
# Modos:  --doctor | --clean | --clean-keep | --update | --list-instances | --remove-all | --open
set -uo pipefail

CLONE="${DSH_CLONE:-$HOME/projects/dsh/dsh-h-v1}"
LIVE="${DSH_LIVE:-$HOME/.dsh-v2}"
CORE_PIN=""
GH="https://raw.githubusercontent.com/marcosmmjr2023/dsh-h-v1/main/installer"

# ── idioma do sistema ──────────────────────────────────────────────
detect_lang() {
  local lc="${LANG:-${LC_ALL:-}}"
  case "${lc,,}" in
    pt*) echo "pt-BR" ;;
    zh*) echo "zh-CN" ;;
    *)   echo "en-US" ;;
  esac
}

say()  { echo "$@"; }
ask()  { local m="$1"; echo -n "$m "; read -r a; echo "$a"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ── detecção de estado ─────────────────────────────────────────────
detect() {
  say ""
  say "====================================================="
  say " ESTADO DA MAQUINA (DeepSeek Harness)  [idioma: $(detect_lang)]"
  say "====================================================="
  have node && say " Node/npm:      [OK] $(node -v 2>/dev/null)" || say " Node/npm:      [FALTA]"
  have git && say " Git:           [OK]" || say " Git:           [FALTA]"
  if [ -d "$CLONE/.git" ]; then
    say " Repo local:    [OK] $(git -C "$CLONE" describe --tags 2>/dev/null || echo '(sem tag)')"
  else
    say " Repo local:    [ausente] ($CLONE)"
  fi
  if npm ls -g "@deepseek-ai/dsh" --depth=0 >/dev/null 2>&1; then say " Core global:   [OK]"; else say " Core global:   [ausente]"; fi
  [ -f "$LIVE/cordis.patch.yml" ] || [ -f "$LIVE/.dsh-version.json" ] && say " Config (live): [OK] ($LIVE)" || say " Config (live): [ausente] ($LIVE)"
  if curl -s -o /dev/null --max-time 2 http://127.0.0.1:3002/ 2>/dev/null; then
    say " FreeLLMAPI:    [no ar :3002]"
  elif [ -d "$HOME/projects/freellmapi/server" ]; then
    say " FreeLLMAPI:    [codigo ok, parado]"
  else
    say " FreeLLMAPI:    [ausente]"
  fi
  local n=0
  for m in "$HOME"/.dsh-envs/*/meta.json; do [ -f "$m" ] && n=$((n+1)); done
  if [ "$n" -gt 0 ]; then
    say " Instancias:    $n"
    for m in "$HOME"/.dsh-envs/*/meta.json; do
      [ -f "$m" ] && { local nm; nm=$(basename "$(dirname "$m")"); local po; po=$(grep -oE '"port"[^0-9]*[0-9]+' "$m" | grep -oE '[0-9]+$'); say "   - $nm  (porta ${po:-?})"; }
    done
  else
    say " Instancias:    nenhuma"
  fi
  say "====================================================="
}

# ── helpers ────────────────────────────────────────────────────────
run_gui() {
  local bin; bin="$(npm root -g 2>/dev/null)/@deepseek-ai/dsh/lib/bin.js"
  [ -f "$bin" ] || { say "[X] core nao encontrado - instale antes."; return 1; }
  [ -d "$LIVE" ] || mkdir -p "$LIVE"
  (curl -s -o /dev/null --max-time 2 http://127.0.0.1:3081/ 2>/dev/null) || {
    say "Subindo a GUI (porta 3081, log: $LIVE/web.log)..."
    env DSH_HOME="$LIVE" DSH_WEB_URL="http://127.0.0.1:3081" \
      setsid nohup node "$bin" --profile web --no-open --port 3081 --host 127.0.0.1 >"$LIVE/web.log" 2>&1 &
    for _ in $(seq 1 15); do sleep 1; curl -s -o /dev/null --max-time 2 http://127.0.0.1:3081/ && break; done
  }
  say "[OK] GUI: http://127.0.0.1:3081"
  if have xdg-open; then (xdg-open http://127.0.0.1:3081 >/dev/null 2>&1 &); fi
}

sync_overlay() {
  [ -d "$CLONE" ] || return 1
  mkdir -p "$LIVE"
  cp -f "$CLONE"/overlay/*.js "$LIVE"/ 2>/dev/null
  if [ -f "$CLONE/overlay/cordis.patch.yml.tpl" ]; then
    DSH_CLONE="$CLONE" DSH_LIVE="$LIVE" bash "$CLONE/tools/render-cordis.sh" >/dev/null 2>&1 || true
  fi
  say "[OK] overlay sincronizado em $LIVE"
}

install_new() {
  have node || { say "[X] Instale Node.js (>=22.19) primeiro: https://nodejs.org"; return 1; }
  mkdir -p "$HOME/projects/dsh"
  if [ ! -d "$CLONE/.git" ]; then
    say "Clonando repositorio..."
    git clone https://github.com/marcosmmjr2023/dsh-h-v1.git "$CLONE"
  else
    git -C "$CLONE" pull --ff-only
  fi
  local pinned; pinned="$(node -e 'const m=require(process.argv[1]);process.stdout.write(m.core.pinned)' "$CLONE/manifest.json" 2>/dev/null || echo 'latest')"
  if npm ls -g "@deepseek-ai/dsh@$pinned" --depth=0 >/dev/null 2>&1; then
    say "core ja instalado: $pinned"
  else
    say "Instalando core $pinned (pode pedir senha sudo se o prefixo for de root)..."
    npm install -g "@deepseek-ai/dsh@$pinned" 2>/dev/null || sudo -n npm install -g "@deepseek-ai/dsh@$pinned" 2>/dev/null || { say "[X] Falha ao instalar core (rode com permissao p/ npm -g)"; return 1; }
  fi
  # pt-BR (segue o idioma: aplica sempre; é inócuo em en/zh)
  if [ -x "$CLONE/core-i18n-pt/tools/apply-pt-core.sh" ]; then
    say "Aplicando pt-BR nos dicionarios do core..."
    "$CLONE/core-i18n-pt/tools/apply-pt-core.sh" --force 2>&1 | tail -3 || true
  fi
  sync_overlay
}

remove_all_instances() {
  local n=0
  for m in "$HOME"/.dsh-envs/*/meta.json; do [ -f "$m" ] && n=$((n+1)); done
  [ "$n" -eq 0 ] && { say "Nenhuma instancia."; return; }
  local c; c="$(ask "Apagar TODAS as $n instancias? Digite 'apagar' para confirmar:")"
  [ "$c" = "apagar" ] || return
  for m in "$HOME"/.dsh-envs/*/meta.json; do
    [ -f "$m" ] && bash "$CLONE/core-i18n-pt/tools/core-env.sh" remove "$(basename "$(dirname "$m")")"
  done
}

clean_full() {
  say ""
  say "[ATENCAO] Isso apaga: repo ($CLONE), config live ($LIVE), core global, instancias."
  local c; c="$(ask "Digite 'limpar' para confirmar (Enter cancela):")"
  [ "$c" = "limpar" ] || { say "Cancelado."; return; }
  remove_all_instances >/dev/null 2>&1 || true
  rm -rf "$LIVE"
  npm uninstall -g "@deepseek-ai/dsh" 2>/dev/null || true
  rm -rf "$CLONE"
  say "Limpo. Rode de novo este instalador e escolha a instalacao."
}

clean_keep() {
  say ""
  say "[MODO: limpa MANTENDO chaves/configuracoes]"
  say "Preserva: .credentials.yaml, settings.yaml, llm-*, editor-assets,"
  say "          .agent-presets, .anonymous-user-id, freeapi.db"
  local c; c="$(ask "Digite 'limpar' para confirmar (Enter cancela):")"
  [ "$c" = "limpar" ] || { say "Cancelado."; return; }
  local bak="$HOME/.dsh-keep-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$bak"
  if [ -d "$LIVE" ]; then
    for k in .credentials.yaml settings.yaml .anonymous-user-id editor-assets .agent-presets freeapi.db; do
      [ -e "$LIVE/$k" ] && cp -rf "$LIVE/$k" "$bak/"
    done
    for d in "$LIVE"/llm-*; do [ -e "$d" ] && cp -rf "$d" "$bak/"; done
  fi
  say "Backup: $bak"
  clean_full >/dev/null 2>&1 || true
  install_new
  mkdir -p "$LIVE"
  cp -rf "$bak"/. "$LIVE"/ 2>/dev/null
  say "[OK] Sistema limpo instalado COM suas chaves/configs (backup em $bak)."
}

open_setup_guide() {
  say "Detalhes completos: docs/SERVER-MAP.md, docs/CORE-UPDATE.md, docs/SYNC.md"
  say "(no repo: $CLONE/docs)"
}

# ── modos não-interativos ─────────────────────────────────────────
case "${1:-}" in
  --doctor)      detect; exit 0 ;;
  --list-instances) ls -d "$HOME"/.dsh-envs/*/ 2>/dev/null || say "nenhuma"; exit 0 ;;
  --remove-all)  remove_all_instances; exit 0 ;;
  --clean)       clean_full; exit 0 ;;
  --clean-keep)  clean_keep; exit 0 ;;
  --update)      install_new; run_gui; exit 0 ;;
  --open)        run_gui; exit 0 ;;
esac

# ── interativo ─────────────────────────────────────────────────────
say "== DeepSeek Harness - Instalador Interativo (Linux) =="
detect

while true; do
  say ""
  say "O que voce quer fazer?"
  say "  1) Instalacao LIMPA total (apaga TUDO e instala novo, sem nada)"
  say "  2) Instalacao LIMPA MANTENDO chaves/configuracoes (importa p/ novo)"
  say "  3) Atualizar/completar instalacao existente (nao apaga nada)"
  [ -n "$(ls -d "$HOME"/.dsh-envs/*/ 2>/dev/null)" ] && say "  4) Gerenciar instancias (remover todas)"
  say "  5) Abrir a GUI (sobe servidor na 3081)"
  say "  0) Sair"
  o="$(ask 'Escolha:')"
  case "$o" in
    1) clean_full ;;
    2) clean_keep ;;
    3) install_new ;;
    4) remove_all_instances ;;
    5) run_gui ;;
    0) say "Tchau!"; break ;;
    *) say "Opcao invalida." ;;
  esac
done
