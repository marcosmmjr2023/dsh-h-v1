#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# render-cordis.sh — gera a config viva cordis.patch.yml a partir do
# template overlay/cordis.patch.yml.tpl, substituindo __DSH_HOME__ pelo
# diretório de config vivo DESTA máquina (caminhos absolutos são locais).
# Chamado automaticamente pelo sync-pull e pelo rollback.
# Uso: tools/render-cordis.sh   (Vars: DSH_CLONE, DSH_LIVE)
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
TPL="$CLONE/overlay/cordis.patch.yml.tpl"
OUT="$LIVE/cordis.patch.yml"

[ -f "$TPL" ] || { echo "ℹ  template $TPL ausente — nada a gerar."; exit 0; }
mkdir -p "$LIVE"
sed "s|__DSH_HOME__|$LIVE|g" "$TPL" > "$OUT"
echo "✔ cordis.patch.yml gerado em $OUT (caminhos desta máquina: $LIVE)"
