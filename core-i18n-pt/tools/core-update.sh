#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# core-update.sh — atualiza/volta o CORE do DeepSeek Harness (manual,
# como um kernel: nada automático). Rode com ROOT (sudo):
#
#   core-update.sh --check                    → mostra instalado em cada prefixo
#   core-update.sh --install <versão>         → instala a versão (ex.: 0.1.2-rc.1)
#   core-update.sh --rollback <versão>        → volta para uma versão anterior
#   core-update.sh --history                  → histórico de versões usadas
#
# O que ele faz por prefixo npm do core (/opt/dsh-tui/* e o global do root):
#   1. grava a versão atual no histórico local (<config viva>/.dsh-core-history.json);
#   2. instala "@deepseek-ai/dsh@<versão>" nesse prefixo;
#   3. reaplica os patches pt-BR quando ainda aplicam; se o contexto mudou,
#      avisa para REGENERAR (nunca remenda à força);
#   4. NÃO reinicia a GUI (o botão do painel/pm2 faz isso).
#
# Vars: DSH_LIVE (config viva p/ histórico; padrão $HOME/.dsh)
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
HIST="$LIVE/.dsh-core-history.json"

# Prefixos npm que contêm o core (cada um resolve o próprio global root)
PREFIXES=()
for cand in /opt/dsh-tui/node /usr; do
  if [ -n "$(npm root -g --prefix "$cand" 2>/dev/null)" ] \
     && [ -f "$(npm root -g --prefix "$cand" 2>/dev/null)/@deepseek-ai/dsh/package.json" ]; then
    PREFIXES+=("$cand")
  fi
done

usage() { sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'; }

glob_root() { npm root -g --prefix "$1" 2>/dev/null || echo "$1/node_modules"; }

version_of() { # prefixo → versão do @deepseek-ai/dsh
  node -e 'try{console.log(require(process.argv[1]+"/@deepseek-ai/dsh/package.json").version)}catch(e){console.log("?")}' "$(glob_root "$1")" 2>/dev/null
}

record_history() { # versãoAntiga nova ok_patches
  mkdir -p "$LIVE"
  node -e '
    const fs=require("fs");
    const h=process.argv[1];
    let list=[]; try{list=JSON.parse(fs.readFileSync(h,"utf8"));}catch{}
    list.unshift({version:process.argv[3], from:process.argv[2], patchesOk:process.argv[4]==="ok", at:process.argv[5]});
    list=list.slice(0,12);
    fs.writeFileSync(h, JSON.stringify(list,null,1)+"\n");
  ' "$HIST" "$1" "$2" "$3" "$(date -Is 2>/dev/null || date -u +%FT%TZ)"
}

reapply_pt() { # prefixo
  local root="$(glob_root "$1")/@deepseek-ai"
  if [ -d "$root/dsh-client-locale" ]; then
    if DSH_CORE_PKGS="$root" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --force >/dev/null 2>&1; then
      echo "    ✔ patches pt-BR reaplicados em $root"
      return 0
    fi
    echo "    ⚠ patches pt-BR NÃO aplicaram limpos em $root — o core mudou de contexto."
    echo "      Regenerar (não remendar): ver core-i18n-pt/README.md → 'Atualizar o core'."
    return 1
  fi
  return 0
}

# parse de --live <dir> (sudo não propaga env; o painel passa o diretório vivo)
while [ "$#" -gt 0 ] && [ "$1" = "--live" ]; do
  LIVE="${2:-$LIVE}"; HIST="$LIVE/.dsh-core-history.json"; shift 2
done
cmd="${1:---check}"
case "$cmd" in
  --check)
    for p in "${PREFIXES[@]:-}"; do echo "prefixo $p → $(version_of "$p")"; done
    [ "${#PREFIXES[@]}" -eq 0 ] && echo "nenhum prefixo do core encontrado"
    ;;
  --history)
    if [ -f "$HIST" ]; then cat "$HIST"; else echo "sem histórico em $HIST ainda"; fi
    ;;
  --install|--rollback)
    VER="${2:-}"
    [ -z "$VER" ] && { echo "ERRO: informe a versão (ex.: --install 0.1.2-rc.1)"; exit 2; }
    case "$VER" in
      *[!0-9A-Za-z._-]*|"") echo "ERRO: versão inválida: $VER"; exit 2 ;;
    esac
    for p in "${PREFIXES[@]:-}"; do
      old="$(version_of "$p")"
      echo "▶ [$p] instalando @deepseek-ai/dsh@$VER (era $old)…"
      if ! npm install -g --prefix "$p" "@deepseek-ai/dsh@$VER" >/tmp/dsh-core-npm.log 2>&1; then
        echo "✋ falha no npm (prefixo $p):"; tail -5 /tmp/dsh-core-npm.log; exit 1
      fi
      new="$(version_of "$p")"
      echo "  ✔ agora: $new"
      pt="ok"
      reapply_pt "$p" || pt="regenerar"
      record_history "$old" "$new" "$pt"
    done
    echo "✔ core $([ "$cmd" = "--rollback" ] && echo rollback || echo atualização) concluído para ${VER}."
    echo "   Reinicie a GUI (o botão do painel reinicia; ou pm2 restart dsh-web-v2)."
    ;;
  -h|--help) usage ;;
  *) echo "opção desconhecida: $1"; usage; exit 2 ;;
esac
