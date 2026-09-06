#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# stamp-version.sh — grava <config viva>/.dsh-version.json com a versão
# instalada do overlay (tag/commit do clone) e o instante da atualização.
# Chamado pelo sync-pull e pelo rollback (o badge de versão lê este arquivo).
# O arquivo é LOCAL da máquina — nunca entra no repo (sync-excludes).
# Uso: tools/stamp-version.sh [ref]
#   sem ref  → versão do HEAD do clone (padrão: sync-pull)
#   com ref  → versão do ref (usado pelo rollback, para o badge mostrar a
#              versão para a qual você voltou)
#   Vars: DSH_CLONE, DSH_LIVE
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
REF="${1:-HEAD}"

VER="$(git -C "$CLONE" describe --tags --abbrev=0 "$REF" 2>/dev/null || git -C "$CLONE" rev-parse --short "$REF" 2>/dev/null || echo "dev")"
SHA="$(git -C "$CLONE" rev-parse "$REF" 2>/dev/null || echo "?")"
TS="$(date -Is 2>/dev/null || date '+%Y-%m-%dT%H:%M:%S%z')"
mkdir -p "$LIVE"
printf '{"version":"%s","commit":"%s","updatedAt":"%s"}\n' "$VER" "$SHA" "$TS" > "$LIVE/.dsh-version.json"
echo "✔ versão gravada em $LIVE/.dsh-version.json: $VER ($TS)"
