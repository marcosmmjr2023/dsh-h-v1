#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# install-sudoers.sh — libera o usuário do harness a executar SOMENTE as
# ferramentas de atualização/rollback do core (sem senha). Rode como ROOT
# uma vez por máquina (ex.: sudo core-i18n-pt/tools/install-sudoers.sh).
# Escopo mínimo (princípio do menor privilégio): apenas estes 2 scripts.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "rode como root: sudo $(basename "$0")"; exit 1; }

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="$(cd "$SELF_DIR/../.." && pwd)"
USER="${SUDO_USER:-${USER:-deploy}}"

# só escreve se o clone estiver num caminho "limpo" (sem espaços/aspas)
case "$CLONE" in
  *" "*|*"'"*|*'"'*) echo "✋ caminho do clone com espaços/aspas — configure na mão."; exit 1 ;;
esac

FILE=/etc/sudoers.d/dsh-core-tools
umask 022
{
  echo "# Libera $USER executar as ferramentas de core do dsh (sem senha). Gerado por:"
  echo "# $CLONE/core-i18n-pt/tools/install-sudoers.sh"
  echo "$USER ALL=(root) NOPASSWD: $CLONE/core-i18n-pt/tools/core-update.sh"
  echo "$USER ALL=(root) NOPASSWD: $CLONE/core-i18n-pt/tools/apply-pt-core.sh"
} > "$FILE"
chmod 440 "$FILE"
visudo -c -f "$FILE" || { rm -f "$FILE"; echo "✋ visudo falhou — arquivo removido."; exit 1; }
echo "✔ sudoers instalado: $USER pode rodar (sem senha):"
echo "   sudo $CLONE/core-i18n-pt/tools/core-update.sh"
echo "   sudo $CLONE/core-i18n-pt/tools/apply-pt-core.sh"
