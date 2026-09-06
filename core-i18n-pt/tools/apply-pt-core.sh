#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# apply-pt-core.sh — aplica/verifica/reverte os patches pt-BR do núcleo
# (core-i18n-pt/patches/*.patch) numa instalação do @deepseek-ai/dsh.
#
# Detecção da raiz dos pacotes (onde ficam @deepseek-ai/dsh-client-*):
#   $DSH_CORE_PKGS  (prioritário — ex.: "$(npm root -g)/@deepseek-ai/dsh/node_modules/@deepseek-ai")
#   senão: /opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
#   senão: /usr/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai
#
# Usa `patch -p1` (os node_modules não são repo git); se `patch` não existir
# (Git for Windows sem o extra), cai para `git apply` dentro de um repo git.
# Idempotente: patch já aplicado é detectado e pulado. Diretório root? rode
# com sudo (este script só avisa).
#
# Uso:
#   apply-pt-core.sh [--check] [--revert] [--force]
#     --check   só testa se os patches aplicam (não altera nada)
#     --revert  desfaz os patches aplicados
#     --force   reaplica mesmo com marcador presente (pós-atualização do core)
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

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

VERSION="$(node -e 'console.log(require(process.argv[1]+"/dsh-client-locale/package.json").version)' "$PKGS" 2>/dev/null || echo "?")"
MARKER="$(dirname "$PKGS")/.dsh-core-pt-applied"
echo "  core dsh-client-locale: $VERSION | marcador: ${MARKER}"

if ! command -v patch >/dev/null 2>&1; then
  if ! git -C "$PKGS" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "✋ 'patch' não encontrado e $PKGS não é um repo git."
    echo "   Instale o patch (ex.: apt install patch) ou rode de um repo git (git apply)."
    exit 1
  fi
fi

if [ "$MODE" = "check" ]; then
  ok=1
  for p in "$PATCH_DIR"/*.patch; do
    [ -e "$p" ] || continue
    if (cd "$PKGS" && patch -p1 --dry-run --batch --forward < "$p" >/dev/null 2>&1); then
      echo "  ✓ aplicaria: $(basename "$p")"
    elif (cd "$PKGS" && patch -p1 --dry-run --batch --reverse < "$p" >/dev/null 2>&1); then
      echo "  ℹ já aplicado: $(basename "$p")"
    else
      echo "  ✗ NÃO aplica limpo: $(basename "$p") (contexto divergente?)"
      ok=0
    fi
  done
  [ "$ok" -eq 1 ] && echo "✔ patches OK para esta instalação." || echo "⚠ revise (use --force após atualizar o core, ou reverta com --revert)."
  exit 0
fi

if [ -f "$MARKER" ] && [ "$MODE" = "apply" ] && [ "$FORCE" -eq 0 ]; then
  echo "ℹ  marcador presente ($(cat "$MARKER")) — patches já aplicados neste core."
  echo "   Se o core foi ATUALIZADO, rode: apply-pt-core.sh --force"
  exit 0
fi

if [ "$MODE" = "apply" ] && [ ! -w "$PKGS/dsh-client-locale" ]; then
  echo "⚠  diretório sem permissão de escrita. Rode com sudo (Linux):"
  echo "   sudo core-i18n-pt/tools/apply-pt-core.sh"
  exit 1
fi

apply_one() {
  local p="$1"
  if [ "$MODE" = "revert" ]; then
    if (cd "$PKGS" && patch -p1 --batch -R < "$p" >/dev/null 2>&1); then
      echo "  ✓ revertido: $(basename "$p")"
      return 0
    fi
    if (cd "$PKGS" && patch -p1 --batch --forward --dry-run < "$p" >/dev/null 2>&1); then
      echo "  ℹ já revertido: $(basename "$p")"
      return 0
    fi
  else
    if (cd "$PKGS" && patch -p1 --batch --forward < "$p" >/dev/null 2>&1); then
      echo "  ✓ aplicado: $(basename "$p")"
      return 0
    fi
    if (cd "$PKGS" && patch -p1 --batch --reverse --dry-run < "$p" >/dev/null 2>&1); then
      echo "  ℹ já aplicado: $(basename "$p")"
      return 0
    fi
  fi
  echo "  ✗ falhou (contexto divergente?): $(basename "$p")"
  return 1
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
    printf 'core=%s patches=%s data=%s\n' "$VERSION" "$(ls "$PATCH_DIR" 2>/dev/null | tr '\n' ' ')" "$(date -Is)" > "$MARKER"
    echo "✔ Patches aplicados. Reinicie a GUI (Settings → Language → Português)."
  fi
else
  echo "✋ houve falha — revise manualmente (diff dos arquivos em $PKGS)."
  exit 1
fi
