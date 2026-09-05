#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# sync-push.sh — PUBLICA suas edições locais
# Copia a config viva (~/.dsh) para o espelho overlay/ do clone e
# faz commit+push. Credenciais/estado local são SEMPRE excluídos
# (sync-excludes.txt) e um guard bloqueia segredos no commit.
# Uso:  tools/sync-push.sh "mensagem do commit" [--tag vX.Y.Z]
# Vars: DSH_CLONE, DSH_LIVE
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
EXCL="$SELF_DIR/sync-excludes.txt"
MSG="sync: atualização da camada personalizada"
TAG=""
while [ $# -gt 0 ]; do
  case "$1" in
    --tag) TAG="${2:-}"; shift 2 ;;
    *) MSG="$1"; shift ;;
  esac
done
MANAGED="$CLONE/overlay"

[ -f "$EXCL" ] || { echo "ERRO: arquivo de exclusões ausente: $EXCL"; exit 1; }
[ -d "$CLONE/.git" ] || { echo "ERRO: $CLONE não é um clone git."; exit 1; }
[ -d "$LIVE" ] || { echo "ERRO: config viva $LIVE não existe."; exit 1; }

echo "▶ sync-push: $LIVE → $CLONE/overlay"

# Integra mudanças remotas antes de publicar as suas
git -C "$CLONE" pull --rebase --quiet || echo "⚠  pull --rebase não limpo; siga com git status."

# Espelha a config viva (excluindo segredos/estado) sobre o espelho do clone
rsync -ac --exclude-from="$EXCL" "$LIVE/" "$MANAGED/"
git -C "$CLONE" add -A overlay

# Guard: bloqueia se algo parecido com credencial entrou no staged
if ! "$SELF_DIR/guard-secrets.sh" --staged; then
  echo "✋ sync-push ABORTADO: o guard detectou possível segredo no staged."
  echo "   Revise: git -C \"$CLONE\" diff --cached --stat   e remova o arquivo do índice:"
  echo "   git -C \"$CLONE\" reset HEAD <arquivo>  (e exclua o segredo do disco)"
  exit 1
fi

if git -C "$CLONE" diff --cached --quiet; then
  echo "ℹ  Nada mudou — nada a publicar."
else
  git -C "$CLONE" commit -m "$MSG"
  if ! git -C "$CLONE" push; then
    echo "✋ Push falhou (autenticação?). Configure: gh auth login  ou  um PAT no credential helper."
    exit 1
  fi
  echo "✔ Publicado: $MSG"
  if [ -n "$TAG" ]; then
    git -C "$CLONE" tag -a "$TAG" -m "$MSG"
    if git -C "$CLONE" push origin "$TAG"; then
      echo "✔ Tag publicada: $TAG  (âncora de rollback — tools/rollback.sh $TAG)"
    else
      echo "⚠ Commit publicado, mas a tag falhou no push."
    fi
  fi
fi
echo "✔ sync-push concluído."
