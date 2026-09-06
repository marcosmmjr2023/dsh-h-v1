#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# apply-pt-core.sh — aplica/verifica/reverte os patches pt-BR do núcleo
# (core-i18n-pt/patches/*.patch) numa instalação do @deepseek-ai/dsh.
#
# Detecção da raiz dos pacotes (onde ficam @deepseek-ai/dsh-client-*):
#   $DSH_CORE_PKGS  (prioritário — ex.: "$(npm root -g)/@deepseek-ai/dsh/node_modules/@deepseek-ai")
#   senão: /opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
#   senão: /usr/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
# Aplica com `git apply` (idempotente): se o arquivo já tem o patch, pula.
# Se o diretório for root (Linux), rode com sudo — este script apenas avisa.
#
# Uso:
#   apply-pt-core.sh [--check] [--revert] [--force]
#     --check   só testa se os patches aplicam (não altera nada)
#     --revert  desfaz os patches aplicados
#     --force   reaplica mesmo com marcador presente (pós-atualização do core)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
PATCH_DIR="$REPO/core-i18n-pt/patches"
MODE="apply"
FORCE=0
for a in "$@"; do
  case "$a" in
    --check) MODE="check" ;;
    --revert) MODE="revert" ;;
    --force) FORCE=1 ;;
    *) echo "opção desconhecida: $a"; exit 2 ;;
  esac
done

candidates=(
  "${DSH_CORE_PKGS:-}"
  /opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
  /usr/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
)
PKGS=""
for c in "${candidates[@]}"; do
  if [ -n "$c" ] && [ -d "$c/dsh-client-locale" ]; then PKGS="$c"; break; fi
done
if [ -z "$PKGS" ]; then
  echo "✋ raiz dos pacotes do core não encontrada."
  echo "   Defina DSH_CORE_PKGS (ex.: \"\$(npm root -g)/@deepseek-ai/dsh/node_modules/@deepseek-ai\")."
  exit 1
fi
echo "▶ raiz de pacotes: $PKGS"

# versão do core (para o marcador e aviso de drift)
VERSION="$(node -e 'console.log(require(process.argv[1]+"/dsh-client-locale/package.json").version)' "$PKGS" 2>/dev/null || echo "?")"
MARKER="$(dirname "$PKGS")/.dsh-core-pt-applied"
echo "  core dsh-client-locale: $VERSION | marcador: ${MARKER}"

if [ "$MODE" = "check" ]; then
  ok=1
  for p in "$PATCH_DIR"/*.patch; do
    [ -e "$p" ] || continue
    if (cd "$PKGS" && git apply --check "$p" 2>/dev/null); then
      echo "  ✓ aplicaria: $(basename "$p")"
    else
      echo "  ✗ NÃO aplicaria limpo: $(basename "$p")"
      ok=0
    fi
  done
  [ "$ok" -eq 1 ] && echo "✔ todos os patches aplicariam (nenhuma alteração feita)." || echo "⚠ alguns patches já estão aplicados ou o core mudou (use --force após atualizar)."
  exit 0
fi

if [ -f "$MARKER" ] && [ "$MODE" = "apply" ] && [ "$FORCE" -eq 0 ]; then
  echo "ℹ  marcador presente ($(cat "$MARKER")) — patches já aplicados neste core."
  echo "   Se o core foi ATUALIZADO, rode: apply-pt-core.sh --force"
  exit 0
fi

# diretório gravável? (root-owned no Linux)
if [ ! -w "$PKGS/dsh-client-locale" ]; then
  echo "⚠  diretório sem permissão de escrita. Rode com sudo (Linux):"
  echo "   sudo core-i18n-pt/tools/apply-pt-core.sh"
  if [ "$MODE" = "apply" ]; then exit 1; fi
fi

apply_one() {
  local p="$1" cmd="apply"
  if [ "$MODE" = "revert" ]; then cmd="-R"; fi
  if (cd "$PKGS" && git apply $cmd "$p"); then
    echo "  ✓ $(basename "$p")"
  else
    # já aplicado (ou contexto divergente)
    if (cd "$PKGS" && git apply --reverse --check "$p" 2>/dev/null); then
      echo "  ℹ já aplicado: $(basename "$p")"
    else
      echo "  ✗ falhou (contexto divergente?): $(basename "$p")"
      return 1
    fi
  fi
}

failed=0
for p in "$PATCH_DIR"/*.patch; do
  [ -e "$p" ] || continue
  apply_one "$p" || failed=1
done

if [ "$failed" -eq 0 ]; then
  if [ "$MODE" = "revert" ]; then
    rm -f "$MARKER"
    echo "✔ Patches revertidos. Reinicie a GUI do harness."
  else
    printf 'core=%s patches=%s data=%s\n' "$VERSION" "$(basename -a "$PATCH_DIR"/*.patch 2>/dev/null | tr '\n' ' ')" "$(date -Is)" > "$MARKER"
    echo "✔ Patches aplicados. Reinicie a GUI (Settings → Language → Português)."
  fi
else
  echo "✋ houve falha — revise os arquivos manualmente (git -C \"$PKGS\" diff --stat)."
  exit 1
fi
