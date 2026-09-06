#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# rollback.sh — volta para uma versão ANTERIOR que funcionava
#
#   tools/rollback.sh list
#       → mostra snapshots locais + tags/commits disponíveis no clone
#   tools/rollback.sh --snapshot <nome|número>
#       → restaura a config viva para um snapshot local (estado exato
#         que funcionava nesta máquina, incluindo edições locais suas)
#   tools/rollback.sh <tag|commit>
#       → volta o overlay para aquela versão do repo (ex.: v1.0.0)
#   tools/rollback.sh --core <versão>
#       → reinstala o CORE (L1) numa versão específica (npm)
#
# Antes de QUALQUER rollback, um snapshot do estado atual é criado
# automaticamente — você sempre pode desfazer o rollback.
# Vars: DSH_CLONE, DSH_LIVE, DSH_SNAP_ROOT
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
SNAP_ROOT="${DSH_SNAP_ROOT:-$HOME/.dsh-snapshots}"
EXCL="$SELF_DIR/sync-excludes.txt"
MANAGED="$CLONE/overlay"

[ -f "$EXCL" ] || { echo "ERRO: $EXCL ausente"; exit 1; }
[ -d "$CLONE/.git" ] || { echo "ERRO: $CLONE não é um clone git"; exit 1; }

# snapshot automático "antes de mexer" (para poder desfazer)
auto_snapshot() {
  "$SELF_DIR/snapshot.sh" create >/dev/null 2>&1 && echo "  (estado atual salvo em snapshot antes do rollback)"
}

# aviso sobre core: pinado no manifest do ref vs instalado
core_warn() {
  local ref="$1" pinned="" installed=""
  pinned="$(git -C "$CLONE" show "$ref:manifest.json" 2>/dev/null | sed -n 's/.*"pinned"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
  if [ -n "$pinned" ]; then
    installed="$(npm ls -g "@deepseek-ai/dsh" --depth=0 2>/dev/null | grep -oE '@deepseek-ai/dsh@[^ ]+' | head -1 | sed 's/.*@//')"
    echo "  core: versão pinada em $ref = $pinned | instalada nesta máquina = ${installed:-?}"
    if [ -n "$installed" ] && [ "$installed" != "$pinned" ]; then
      echo "  ➜ Se quebras vierem do core, reflita:  tools/rollback.sh --core $pinned"
    fi
  fi
}

case "${1:-list}" in
  list)
    echo "═ Snapshots locais ($SNAP_ROOT) — estado exato que funcionava nesta máquina ═"
    "$SELF_DIR/snapshot.sh" list
    echo
    echo "═ Tags (versões publicadas conhecidas) ═"
    if [ -z "$(git -C "$CLONE" tag)" ]; then
      echo "  (nenhuma tag ainda — publique com: tools/sync-push.sh 'msg' --tag v0.1.0)"
    else
      git -C "$CLONE" tag -l --sort=-creatordate | head -15 | sed 's/^/  /'
    fi
    echo
    echo "═ Commits recentes do overlay ═"
    git -C "$CLONE" log --oneline -12 | sed 's/^/  /'
    echo
    echo "Uso:"
    echo "  tools/rollback.sh --snapshot <nome|número>   restaurar um snapshot local"
    echo "  tools/rollback.sh <tag|commit>               voltar o overlay a uma versão do repo"
    echo "  tools/rollback.sh --core <versão>            reinstalar o core (npm)"
    ;;

  --snapshot)
    shift
    [ $# -lt 1 ] && { echo "ERRO: informe o snapshot (nome ou número da lista)."; exit 2; }
    auto_snapshot
    sel="$1"
    if [[ "$sel" =~ ^[0-9]+$ ]]; then
      picked="$(find "$SNAP_ROOT" -maxdepth 1 -type d -name 'snap-*' -printf '%f\n' | sort -r | sed -n "${sel}p")"
      dest="${picked:+$SNAP_ROOT/$picked}"
    else
      dest="$SNAP_ROOT/$sel"
    fi
    [ -d "$dest" ] || { echo "ERRO: snapshot '$sel' não encontrado (tools/rollback.sh list)"; exit 1; }
    echo "▶ Restaurando snapshot: $(basename "$dest") → $LIVE"
    rsync -ac --delete --exclude-from="$EXCL" "$dest/" "$LIVE/"
    echo "✔ Config viva restaurada do snapshot $(basename "$dest")."
    echo "  (Reinicie o harness para carregar o estado restaurado.)"
    ;;

  --core)
    shift
    [ $# -lt 1 ] && { echo "ERRO: informe a versão (ex.: tools/rollback.sh --core 0.1.1-rc.2)"; exit 2; }
    echo "▶ Reinstalando core @deepseek-ai/dsh@$1"
    npm install -g "@deepseek-ai/dsh@$1"
    echo "✔ Core $1 instalado. Teste seus plugins e, se estável, atualize o pinned no manifest.json."
    ;;

  -*)
    echo "Opção desconhecida: $1"; exit 2 ;;

  *)
    ref="$1"
    git -C "$CLONE" rev-parse --verify "$ref^{commit}" >/dev/null 2>&1 || { echo "ERRO: '$ref' não é tag/commit válido no clone."; exit 1; }
    auto_snapshot
    echo "▶ Voltando overlay para: $ref"
    tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
    git -C "$CLONE" archive "$ref" overlay | tar -x -C "$tmp" 2>/dev/null

    # arquivos que existem no HEAD atual mas não no ref → remover (do espelho e da config viva)
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      rm -f "$CLONE/$f" "$LIVE/${f#overlay/}"
      echo "  removido: ${f#overlay/}"
    done < <(comm -23 \
        <(git -C "$CLONE" ls-tree -r --name-only HEAD -- overlay | sort) \
        <(git -C "$CLONE" ls-tree -r --name-only "$ref" -- overlay | sort))

    # conteúdo do ref → espelho → config viva
    rsync -ac --exclude-from="$EXCL" "$tmp/overlay/" "$MANAGED/"
    rsync -ac --exclude-from="$EXCL" "$MANAGED/" "$LIVE/"
    # regenera cordis.patch.yml local (caminhos desta máquina) conforme o ref
    "$SELF_DIR/render-cordis.sh"
    # grava a versão do REF (o badge mostra para qual versão você voltou)
    "$SELF_DIR/stamp-version.sh" "$ref"
    echo "✔ Overlay restaurado para $ref."
    core_warn "$ref"
    echo "  (Reinicie o harness para carregar a versão antiga.)"
    ;;
esac
