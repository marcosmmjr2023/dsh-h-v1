#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# guard-secrets.sh — bloqueia commit/push com possíveis segredos
# Uso:  tools/guard-secrets.sh            (examina git diff --cached)
#       tools/guard-secrets.sh <caminho>  (examina um arquivo/pasta)
# Saída: 0 = limpo | 1 = encontrou algo suspeito
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

PATTERNS=(
  '(^|/)\.credentials\.yaml'          # arquivo de credenciais do DSH
  'ghp_[A-Za-z0-9]{20,}'              # GitHub PAT classic
  'github_pat_[A-Za-z0-9_]{20,}'      # GitHub PAT fine-grained
  'gho_[A-Za-z0-9]{20,}'              # GitHub OAuth
  'sk-[A-Za-z0-9_.-]{16,}'            # chaves OpenAI/DeepSeek-style (ex.: sk-proj-...)
  'AIza[0-9A-Za-z_-]{20,}'            # Google API key
  'AKIA[0-9A-Z]{16}'                  # AWS access key
  'xox[baprs]-[0-9A-Za-z-]{10,}'      # Slack tokens
  '-----BEGIN [A-Z ]*PRIVATE KEY-----' # chaves privadas PEM
  '(api[_-]?key|apikey|auth[_-]?token|access[_-]?token)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_\-\.]{24,}'
  'Bearer[[:space:]]+[A-Za-z0-9_\-\.]{24,}'
)

scan_text() {
  # $1 = texto a varrer; imprime o padrão (não o valor) quando casa.
  # Rápido: um grep por padrão sobre o texto inteiro (sem loop linha-a-linha).
  local text="$1" i=0
  [ -z "$text" ] && return 0
  for pat in "${PATTERNS[@]}"; do
    i=$((i + 1))
    if printf '%s' "$text" | grep -qE -- "$pat"; then
      echo "  padrão $i casou: /$pat/"
    fi
  done
}

found=0

if [ "${1:-}" = "--staged" ]; then
  echo "🔎 guard: varrendo mudanças staged..."
  # Arquivos de nome perigoso (ex.: alguém staged .credentials.yaml)
  bad_names="$(git diff --cached --name-only | grep -E '(^|/)\.credentials\.yaml|\.credentials\.yaml\.bak' || true)"
  if [ -n "$bad_names" ]; then
    echo "✋ Arquivos de credencial no staged:"; echo "$bad_names"; found=1
  fi
  out="$(scan_text "$(git diff --cached)")"
  if [ -n "$out" ]; then echo "✋ Conteúdo suspeito no staged:"; echo "$out"; found=1; fi
elif [ -n "${1:-}" ]; then
  echo "🔎 guard: varrendo $1"
  if [ -f "$1" ]; then
    out="$(scan_text "$(cat "$1")")"
    [ -n "$out" ] && { echo "✋ $1:"; echo "$out"; found=1; }
  else
    while IFS= read -r -d '' f; do
      out="$(scan_text "$(cat "$f" 2>/dev/null)")"
      [ -n "$out" ] && { echo "✋ $f:"; echo "$out"; found=1; }
    done < <(find "$1" -type f -print0)
  fi
else
  echo "🔎 guard: varrendo git diff --cached"
  out="$(scan_text "$(git diff --cached)")"
  [ -n "$out" ] && { echo "✋ Conteúdo suspeito no staged:"; echo "$out"; found=1; }
fi

[ "$found" -eq 0 ] && echo "✔ guard: nada suspeito."
exit "$found"
