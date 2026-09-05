#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# install-hooks.sh — instala o guard de segredos como pre-commit
# do clone local (cada máquina roda uma vez após clonar).
# Uso: tools/install-hooks.sh
# ═══════════════════════════════════════════════════════════════
set -euo pipefail
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
HOOK="$CLONE/.git/hooks/pre-commit"
mkdir -p "$CLONE/.git/hooks"
cat > "$HOOK" <<'EOF'
#!/usr/bin/env bash
# Instalado por tools/install-hooks.sh — bloqueia commits com segredos
exec "$(git rev-parse --show-toplevel)/tools/guard-secrets.sh" --staged
EOF
chmod +x "$HOOK"
echo "✔ Hook pre-commit instalado em $HOOK"
