#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# auto-sync.sh — ciclo completo numa linha (Linux/WSL)
# 1) sync-pull  : recebe do GitHub o que as outras máquinas publicaram
#                 (snapshot + aplica overlay + stamp de versão)
# 2) auto-push  : publica as suas edições da config viva (documentadas,
#                 com versão vX.Y.Z e CHANGELOG) — via de mão dupla
# Uso (cron, a cada 30 min): */30 * * * * ~/dsh-h-v1/tools/auto-sync.sh >> ~/.dsh-sync.log 2>&1
# Vars: DSH_CLONE (padrão: pasta pai de tools/), DSH_LIVE (padrão: ~/.dsh)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$SELF_DIR/sync-pull.sh"
"$SELF_DIR/auto-push.sh"
