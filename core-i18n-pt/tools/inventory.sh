#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# inventory.sh — inventário dos dicionários de UI do núcleo (p/ dimensionar
# a tradução pt-BR). Varre a raiz de pacotes (DSH_CORE_PKGS ou auto-detect)
# e lista, por pacote, os arquivos compilados com dicionários de locale e o
# nº aproximado de chaves por dicionário zh/en.
#
# Uso: tools/inventory.sh [--json]
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSON=0
[ "${1:-}" = "--json" ] && JSON=1

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
  echo "raiz de pacotes não encontrada (defina DSH_CORE_PKGS)." >&2
  exit 1
fi

VER="$(node -e 'console.log(require(process.argv[1]+"/dsh-client-locale/package.json").version)' "$PKGS" 2>/dev/null || echo '?')"
echo "# Inventário de dicionários de locale — core @deepseek-ai/dsh $VER (raiz: $PKGS)" >&2

if [ "$JSON" -eq 1 ]; then
  echo "["
  first=1
fi
n=0
while IFS= read -r f; do
  pkg="$(basename "$(dirname "$(dirname "$f")")")"
  zh="$(grep -cE '^\s*const zh\$?\w* = \{|^\s*"zh"\s*:' "$f" 2>/dev/null || true)"
  en="$(grep -cE '^\s*const en\$?\w* = \{|^\s*"en"\s*:' "$f" 2>/dev/null || true)"
  regs="$(grep -cE '\.register\(|locale\.register\(' "$f" 2>/dev/null || true)"
  keys="$(grep -cE '^\s*"[^"\\]+"\s*:' "$f" 2>/dev/null || true)"
  n=$((n + 1))
  if [ "$JSON" -eq 1 ]; then
    [ "$first" -eq 0 ] && printf ",\n"
    first=0
    printf '  {"pkg":"%s","file":"%s","zhDicts":%s,"enDicts":%s,"registerCalls":%s,"approxKeys":%s}' \
      "$pkg" "${f#"$PKGS"/}" "$zh" "$en" "$regs" "$keys"
  else
    printf '%-46s %-70s zh=%s en=%s regs=%s keys~%s\n' "$pkg" "${f#"$PKGS"/}" "$zh" "$en" "$regs" "$keys"
  fi
done < <(grep -rlE 'const zh\$?[0-9]* = \{|\.register\(\s*"' "$PKGS"/@deepseek-ai/dsh-client-* "$PKGS"/dsh-client-* 2>/dev/null | sort -u)
if [ "$JSON" -eq 1 ]; then
  echo
  echo "]"
else
  echo "# $n arquivo(s) com dicionários (aprox. — confirme chaves ao traduzir)."
fi
