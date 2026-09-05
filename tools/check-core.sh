#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# check-core.sh — versão do CORE do DeepSeek Harness (L1)
# Compara: instalado nesta máquina × pinada no manifest.json × latest npm.
# Política atual: NOTIFICAR (atualização do core é manual e testada).
# Uso: tools/check-core.sh
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
PKG="@deepseek-ai/dsh"

# Versão pinada (conhecida-boa) no manifest.json
PINNED="$(sed -n 's/.*"pinned"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$CLONE/manifest.json" 2>/dev/null | head -1)"
[ -n "$PINNED" ] || PINNED="(manifest.json sem pinned)"

# Versão instalada nesta máquina (global npm)
INSTALLED="${DSH_INSTALLED_VERSION:-}"
if [ -z "$INSTALLED" ]; then
  INSTALLED="$(npm ls -g "$PKG" --depth=0 2>/dev/null | grep -oE "@deepseek-ai/dsh@[^ ]+" | head -1 | sed 's/.*@//')"
fi
if [ -z "$INSTALLED" ]; then
  for P in /usr/lib/node_modules/@deepseek-ai/dsh/package.json /usr/local/lib/node_modules/@deepseek-ai/dsh/package.json; do
    [ -f "$P" ] && INSTALLED="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$P" | head -1)" && break
  done
fi
[ -n "$INSTALLED" ] || INSTALLED="(não encontrado via npm ls -g)"

# Versão mais recente no registro oficial
LATEST="$(npm view "$PKG" version 2>/dev/null || echo "indisponível (sem rede?)")"

echo "── Core do DeepSeek Harness ──────────────────────────────"
echo "  instalado nesta máquina : $INSTALLED"
echo "  pinado no manifest.json : $PINNED"
echo "  latest no npm           : $LATEST"
echo "──────────────────────────────────────────────────────────"

if [ "$LATEST" != "indisponível (sem rede?)" ] && [ "$INSTALLED" != "$LATEST" ]; then
  echo "➜ Há uma versão NOVA do core ($LATEST). Política: notificar e aplicar manualmente."
  echo "  Antes de atualizar, confira a compatibilidade dos seus plugins (overlay/)."
  echo "  Para atualizar (teste antes!):  npm update -g $PKG"
fi
if [ -n "$PINNED" ] && [ "$INSTALLED" != "$(echo "$PINNED" | tr -d '()')" ] && [ "$PINNED" != "(manifest.json sem pinned)" ]; then
  echo "ℹ  A versão instalada difere da pinada ($PINNED). Se estabilizou, atualize o pinned no manifest.json."
fi
