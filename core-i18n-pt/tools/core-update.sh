#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# core-update.sh — atualiza/volta o CORE do DeepSeek Harness com SEGURANÇA
# (manual, como um kernel — nada automático). Rode como ROOT (sudo):
#
#   core-update.sh --check                       → versões instaladas
#   core-update.sh --history                     → histórico de versões
#   core-update.sh --preview <versão>            → TESTA candidato isolado
#   core-update.sh --install <versão>            → backup + preview + instala
#   core-update.sh --rollback <versão>           → volta (backup + restaura)
#
# Garantias:
#   1. BACKUP completo antes de qualquer operação (core-backup.sh): sessões,
#      config, credenciais, plugins, manifesto do core — em
#      ~/.dsh-core-backups/ (nunca sincronizado).
#   2. PREVIEW isolado (por padrão no --install): instala o candidato num
#      prefixo de teste, aplica os patches pt e sobe a GUI de teste; só passa
#      se a GUI responder 200 (token incluso) e os plugins do overlay
#      carregarem. Falhou → nada é aplicado na máquina real.
#   3. Rollback simples: --rollback <versão-anterior> (e botão ↩ no painel).
#   4. NUNCA reinicia a GUI sozinho — você decide quando aplicar (botão).
#
# Vars: DSH_LIVE (config viva p/ histórico; padrão $HOME/.dsh)
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
HIST="$LIVE/.dsh-core-history.json"
DO_BACKUP=1
DO_PREVIEW=1

while [ "$#" -gt 0 ]; do
  case "$1" in
    --live) LIVE="${2:-$LIVE}"; HIST="$LIVE/.dsh-core-history.json"; shift 2 ;;
    --skip-backup) DO_BACKUP=0; shift ;;
    --skip-preview) DO_PREVIEW=0; shift ;;
    *) break ;;
  esac
done

PREFIXES=()
for cand in /opt/dsh-tui/node /usr; do
  if [ -n "$(npm root -g --prefix "$cand" 2>/dev/null)" ] \
     && [ -f "$(npm root -g --prefix "$cand" 2>/dev/null)/@deepseek-ai/dsh/package.json" ]; then
    PREFIXES+=("$cand")
  fi
done

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }
glob_root() { npm root -g --prefix "$1" 2>/dev/null || echo "$1/node_modules"; }
version_of() { node -e 'try{console.log(require(process.argv[1]+"/@deepseek-ai/dsh/package.json").version)}catch(e){console.log("?")}' "$(glob_root "$1")" 2>/dev/null; }

record_history() {
  mkdir -p "$LIVE"
  node -e '
    const fs=require("fs"); const h=process.argv[1];
    let list=[]; try{list=JSON.parse(fs.readFileSync(h,"utf8"));}catch{}
    list.unshift({version:process.argv[3], from:process.argv[2], patchesOk:process.argv[4]==="ok", at:process.argv[5]});
    list=list.slice(0,12);
    fs.writeFileSync(h, JSON.stringify(list,null,1)+"\n");
  ' "$HIST" "$1" "$2" "$3" "$(date -Is 2>/dev/null || date -u +%FT%TZ)"
}

apply_pt_root() { # root-do-prefixo (…/node_modules) → dir de deps do app
  local root="$1" dep=""
  if [ -d "$root/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-locale" ]; then
    dep="$root/@deepseek-ai/dsh/node_modules/@deepseek-ai"
  elif [ -d "$root/@deepseek-ai/dsh-client-locale" ]; then
    dep="$root/@deepseek-ai"
  else
    return 0
  fi
  if DSH_CORE_PKGS="$dep" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --check >/dev/null 2>&1; then
    if DSH_CORE_PKGS="$dep" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --force >/dev/null 2>&1; then
      echo "    ✔ patches pt-BR em $dep"
    fi
  else
    echo "    ℹ patches antigos não encaixam neste core — usando regeneração (pt-ride)…"
  fi
  if node "$REPO/core-i18n-pt/tools/pt-ride.mjs" --root "$dep" >/dev/null 2>&1; then
    echo "    ✔ pt-BR garantido via pt-ride"
    return 0
  fi
  echo "    ⚠ pt-BR incompleto em $dep — confira a tabela de traduções."
  return 1
}

# ── PREVIEW: instala o candidato num prefixo isolado, aplica pt, sobe GUI de
#    teste com os plugins do overlay e exige http 200 (aceitando token novo).
preview_candidate() {
  local ver="$1" stg="$HOME/.dsh-core-staging" port=0 log
  rm -rf "$stg"; mkdir -p "$stg"
  echo "▶ [preview] instalando @deepseek-ai/dsh@$ver em prefixo isolado $stg …"
  if ! npm install -g --prefix "$stg" "@deepseek-ai/dsh@$ver" >"$HOME/.dsh-core-preview-npm.log" 2>&1; then
    echo "✋ [preview] falha no npm (candidato nem instala)."; tail -4 "$HOME/.dsh-core-preview-npm.log"; rm -rf "$stg"; return 1
  fi
  local sroot; sroot="$(npm root -g --prefix "$stg" 2>/dev/null)"
  local sdep=""
  if [ -d "$sroot/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-locale" ]; then sdep="$sroot/@deepseek-ai/dsh/node_modules/@deepseek-ai"; else sdep="$sroot/@deepseek-ai"; fi
  if DSH_CORE_PKGS="$sdep" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --force >/dev/null 2>&1; then
    echo "    ✔ patches pt-BR no preview"
  else
    echo "    ⚠ pt-BR não aplicou no preview (contexto?) — seguindo."
  fi
  # home de teste: plugins do overlay + settings (sem credenciais/sessões)
  local tmph; tmph="$(mktemp -d /tmp/dsh-preview-home.XXXXXX)"
  for h in /home/deploy/.dsh /home/deploy/.dsh-v2; do
    [ -d "$h" ] || continue
    for f in "$h"/*.js; do [ -f "$f" ] && cp -a "$f" "$tmph/"; done 2>/dev/null
    [ -f "$h/settings.yaml" ] && cp -a "$h/settings.yaml" "$tmph/"
  done
  # resolve plugins de perfil pelo prefixo isolado (como o home real faz)
  mkdir -p "$tmph/profiles/node_modules/@deepseek-ai"
  for pkg in "$sroot"/@deepseek-ai/*; do
    [ -d "$pkg" ] && ln -s "$pkg" "$tmph/profiles/node_modules/@deepseek-ai/$(basename "$pkg")" 2>/dev/null
  done
  # escolhe porta livre (30xx)
  port=$((3100 + RANDOM % 900))
  log="$HOME/.dsh-core-preview-$port.log"
  cd /home/deploy || true
  env DSH_HOME="$tmph" DSH_WEB_URL="http://127.0.0.1:$port" \
    node "$sroot/@deepseek-ai/dsh/lib/bin.js" --profile web --no-open --port "$port" --host 127.0.0.1 \
    >"$log" 2>&1 &
  local pid=$! ok="" code=""
  for i in $(seq 1 60); do
    code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" 2>/dev/null || true)
    if [ "$code" = "200" ]; then ok=1; break; fi
    if [ "$code" = "401" ]; then
      token="$(grep -oE '\?token=[A-Za-z0-9_-]+' "$log" | head -1)"
      if [ -n "$token" ]; then
        code2=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/$token" 2>/dev/null || true)
        [ "$code2" = "200" ] && { ok=1; echo "  ℹ [preview] candidato usa AUTENTICAÇÃO por token ($token)."; break; }
      fi
      break
    fi
    sleep 2
  done
  local plugins=0
  grep -q '\[VersionBadge\]' "$log" && plugins=1
  kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null
  if [ -n "$ok" ] && [ "$plugins" -eq 1 ]; then
    echo "✔ [preview] $ver PASSOU (GUI 200 + plugins do overlay carregados)."
    rm -rf "$stg" "$tmph"
    return 0
  fi
  echo "✋ [preview] $ver FALHOU (http=${code:-sem resposta}, plugins_carregados=$plugins). Log: $log"
  [ "$plugins" -eq 0 ] && echo "   ➜ os plugins do overlay não carregaram — precisa adaptá-los antes de subir este core."
  grep -nE 'error:|Error:|updateError' "$log" | head -5
  rm -rf "$stg" "$tmph"
  return 1
}

cmd="${1:---check}"
case "$cmd" in
  --check)
    for p in "${PREFIXES[@]:-}"; do echo "prefixo $p → $(version_of "$p")"; done
    [ "${#PREFIXES[@]}" -eq 0 ] && echo "nenhum prefixo do core encontrado"
    ;;
  --history) [ -f "$HIST" ] && cat "$HIST" || echo "sem histórico em $HIST ainda" ;;
  --preview)
    VER="${2:-}"; [ -n "$VER" ] || { echo "ERRO: informe a versão (--preview 0.1.2-rc.1)"; exit 2; }
    preview_candidate "$VER"
    ;;
  --install|--rollback)
    VER="${2:-}"
    [ -z "$VER" ] && { echo "ERRO: informe a versão (ex.: --install 0.1.2-rc.1)"; exit 2; }
    case "$VER" in *[!0-9A-Za-z._-]*|"") echo "ERRO: versão inválida: $VER"; exit 2 ;; esac
    if [ "$cmd" = "--install" ] && [ "$DO_PREVIEW" -eq 1 ]; then
      preview_candidate "$VER" || { echo "✋ Abortado: candidato NÃO passou no preview — nada foi alterado na máquina real."; exit 1; }
    fi
    if [ "$DO_BACKUP" -eq 1 ]; then
      echo "▶ backup pré-operação…"
      "$SELF_DIR/core-backup.sh" --label "pre-${cmd#--}-${VER}" >/dev/null 2>&1 && echo "  ✔ backup em ~/.dsh-core-backups/"
    fi
    for p in "${PREFIXES[@]:-}"; do
      old="$(version_of "$p")"
      echo "▶ [$p] instalando @deepseek-ai/dsh@$VER (era $old)…"
      if ! npm install -g --prefix "$p" "@deepseek-ai/dsh@$VER" >/tmp/dsh-core-npm.log 2>&1; then
        echo "✋ falha no npm (prefixo $p):"; tail -5 /tmp/dsh-core-npm.log; exit 1
      fi
      new="$(version_of "$p")"
      echo "  ✔ agora: $new"
      pt="ok"; apply_pt_root "$(glob_root "$p")" || pt="regenerar"
      record_history "$old" "$new" "$pt"
    done
    echo "✔ core $([ "$cmd" = "--rollback" ] && echo rollback || echo atualização) para ${VER} concluído."
    echo "   A GUI ainda NÃO foi reiniciada — aplique quando quiser (botão no painel ou pm2 restart dsh-web-v2)."
    echo "   Se algo falhar depois de reiniciar:  sudo core-i18n-pt/tools/core-update.sh --rollback <versão-anterior>"
    echo "   Dados restauram em: core-restore.sh latest"
    ;;
  -h|--help) usage ;;
  *) echo "opção desconhecida: $1"; usage; exit 2 ;;
esac
