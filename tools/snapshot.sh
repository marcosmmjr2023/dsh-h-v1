#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# snapshot.sh — cria/lista snapshots da config viva ANTES de mudar
# Princípio do rollback: nunca substituir o que está funcionando sem
# antes guardar uma cópia local dele.
#
#   tools/snapshot.sh create   → ~/.dsh-snapshots/snap-<data>-<hash>/
#   tools/snapshot.sh list     → lista snapshots (mais recente primeiro)
#   tools/snapshot.sh prune    → apaga snapshots além de SNAP_KEEP (8)
# Vars: DSH_CLONE, DSH_LIVE, DSH_SNAP_ROOT (padrão ~/.dsh-snapshots), SNAP_KEEP
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
SNAP_ROOT="${DSH_SNAP_ROOT:-$HOME/.dsh-snapshots}"
KEEP="${SNAP_KEEP:-8}"
EXCL="$SELF_DIR/sync-excludes.txt"

[ -f "$EXCL" ] || { echo "ERRO: $EXCL ausente"; exit 1; }
[ -d "$LIVE" ] || { echo "ERRO: config viva $LIVE não existe"; exit 1; }

cmd="${1:-list}"

case "$cmd" in
  create)
    mkdir -p "$SNAP_ROOT"
    hash="$(git -C "$CLONE" rev-parse --short HEAD 2>/dev/null || echo "sem-git")"
    base="snap-$(date +%Y%m%d-%H%M%S)-$hash"
    name="$base"; n=2
    while [ -e "$SNAP_ROOT/$name" ]; do name="$base-$n"; n=$((n + 1)); done
    dest="$SNAP_ROOT/$name"
    rsync -a --exclude-from="$EXCL" "$LIVE/" "$dest/"
    echo "✔ snapshot criado: $dest"
    # manutenção: mantém apenas as $KEEP mais recentes
    count=0
    for d in $(ls -1dt "$SNAP_ROOT"/snap-* 2>/dev/null); do
      count=$((count + 1))
      if [ "$count" -gt "$KEEP" ]; then
        rm -rf "$d"
        echo "  (removido snapshot antigo: $(basename "$d"))"
      fi
    done
    ;;
  list)
    if ! ls -1dt "$SNAP_ROOT"/snap-* >/dev/null 2>&1; then
      echo "ℹ  Nenhum snapshot em $SNAP_ROOT ainda."
      exit 0
    fi
    echo "Snapshots em $SNAP_ROOT (mais recente primeiro):"
    i=0
    for d in $(ls -1dt "$SNAP_ROOT"/snap-* 2>/dev/null); do
      i=$((i + 1))
      echo "  $i) $(basename "$d")"
    done
    ;;
  prune)
    count=0
    for d in $(ls -1dt "$SNAP_ROOT"/snap-* 2>/dev/null); do
      count=$((count + 1))
      if [ "$count" -gt "$KEEP" ]; then rm -rf "$d"; fi
    done
    echo "✔ prune concluído (mantidos $KEEP)."
    ;;
  *)
    echo "Uso: tools/snapshot.sh {create|list|prune}"; exit 2 ;;
esac
