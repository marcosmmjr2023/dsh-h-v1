#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# sync-pull.sh — RECEBE atualizações
# Puxa o repo e aplica overlay/ sobre a config viva (~/.dsh).
# Uso:  tools/sync-pull.sh
# Vars: DSH_CLONE (padrão: pasta pai de tools/), DSH_LIVE (padrão: ~/.dsh)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
EXCL="$SELF_DIR/sync-excludes.txt"

[ -f "$EXCL" ] || { echo "ERRO: arquivo de exclusões ausente: $EXCL"; exit 1; }
[ -d "$CLONE/.git" ] || { echo "ERRO: $CLONE não é um clone git. Clone o repo e rode este script de dentro dele."; exit 1; }

echo "▶ sync-pull: $CLONE/overlay → $LIVE"

if ! git -C "$CLONE" pull --ff-only --quiet; then
  echo "⚠  Pull falhou. Há alterações locais não commitadas no clone?"
  echo "   (git -C \"$CLONE\" status)  — rode tools/sync-push.sh primeiro, se for o caso."
  exit 1
fi

# 1) Snapshot do estado ATUAL (o que está funcionando agora) — para rollback
"$SELF_DIR/snapshot.sh" create || true

# 2) Aplica o overlay novo sobre a config viva
mkdir -p "$LIVE"
rsync -ac --exclude-from="$EXCL" "$CLONE/overlay/" "$LIVE/"
echo "✔ overlay aplicado em $LIVE"

# Gera cordis.patch.yml local a partir do template (caminhos desta máquina)
"$SELF_DIR/render-cordis.sh"

# Grava versão instalada + instante (para o badge de versão)
"$SELF_DIR/stamp-version.sh"

# Aviso sobre o core (L1) — informativo, não bloqueia
if [ -x "$SELF_DIR/check-core.sh" ]; then "$SELF_DIR/check-core.sh" || true; fi
echo "✔ sync-pull concluído. Rollback disponível: tools/rollback.sh list"
