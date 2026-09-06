#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# release.sh — PUBLICA A SUB-VERSÃO do estado atual (mudanças estruturais)
#
# Quando as versões não sobem sozinhas:
#   • auto-push (cron) versiona TODA edição nova da CONFIG VIVA (~/.dsh);
#   • mas mudanças ESTRUTURAIS enviadas direto por git/sync-push (tools/,
#     docs/, README, overlay manual, pin do core) ficam SEM versão nova —
#     a tag continua a última e o badge não muda.
# release.sh fecha essa lacuna: marca o estado atual (já commitado/enviado)
# com a próxima sub-versão vX.Y.Z e uma entrada no CHANGELOG.md resumindo
# os commits desde a última tag.
#
# Uso:  tools/release.sh [--dry-run]
# Vars: DSH_CLONE (padrão: pasta pai de tools/)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
CHLOG="$CLONE/CHANGELOG.md"
MODE="${1:-}"
HOST="$(hostname 2>/dev/null || echo "esta-maquina")"

[ -d "$CLONE/.git" ] || { echo "ERRO: $CLONE não é um clone git."; exit 1; }

bump_patch() {
  local v="$1" maj min pat
  v="${v#v}"
  IFS=. read -r maj min pat <<<"$v"
  echo "v${maj}.${min}.$((pat + 1))"
}

next_version() {
  local latest base
  git -C "$CLONE" fetch -q --tags origin 2>/dev/null || true
  latest="$(git -C "$CLONE" tag --list 'v[0-9]*' --sort=-version:refname 2>/dev/null | head -1 || true)"
  if [ -n "$latest" ]; then bump_patch "$latest"; return 0; fi
  base="$(grep -m1 '"version"' "$CLONE/manifest.json" 2>/dev/null \
    | sed -E 's/.*"version"[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true)"
  [ -n "$base" ] || base="0.1.0"
  bump_patch "$base"
}

# ── Integra o remoto (só fast-forward; nada de forçar) ─────────
git -C "$CLONE" fetch -q origin 2>/dev/null || true
if ! git -C "$CLONE" merge-base --is-ancestor '@{u}' HEAD 2>/dev/null; then
  echo "✋ ERRO: este clone está ATRÁS do remoto — rode antes: tools/sync-pull.sh (ou git pull --ff-only)."
  exit 1
fi
AHEAD="$(git -C "$CLONE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
if [ "${AHEAD:-0}" -gt 0 ]; then
  echo "⚠  há ${AHEAD} commit(s) locais não enviados — enviando antes do release."
  git -C "$CLONE" push --quiet || { echo "✋ Push falhou (autenticação?)."; exit 1; }
fi

# ── Última tag e distância do estado atual ──────────────────────
LAST_TAG="$(git -C "$CLONE" tag --list 'v[0-9]*' --sort=-version:refname 2>/dev/null | head -1 || true)"
if [ -n "$LAST_TAG" ]; then
  DIST="$(git -C "$CLONE" rev-list --count "$LAST_TAG..HEAD" 2>/dev/null || echo 0)"
  if [ "${DIST:-0}" -eq 0 ]; then
    echo "ℹ  Nada a lançar: HEAD já está na última versão ($LAST_TAG)."
    exit 0
  fi
else
  DIST="$(git -C "$CLONE" rev-list --count HEAD 2>/dev/null || echo 0)"
  echo "ℹ  Nenhuma tag de versão ainda — primeira release."
fi
V="$(next_version)"

# ── Resumo desde a última tag (entrada do CHANGELOG) ───────────
COMMITS="$(git -C "$CLONE" log --oneline "${LAST_TAG:-$(git -C "$CLONE" rev-list --max-parents=0 HEAD)}..HEAD" 2>/dev/null || git -C "$CLONE" log --oneline | head -50)"
COMMIT_N="$(printf '%s\n' "$COMMITS" | grep -cv '^$' || true)"
NOW="$(date '+%Y-%m-%d %H:%M')"

if [ "$MODE" = "--dry-run" ]; then
  echo "▶ [dry-run] release: $V — ${COMMIT_N:-0} commit(s) desde ${LAST_TAG:-início}"
  printf '%s\n' "$COMMITS" | head -20 | sed 's/^/    /'
  echo "✔ [dry-run] nada foi alterado. Para publicar: tools/release.sh"
  exit 0
fi

# ── CHANGELOG.md (cria com cabeçalho se ainda não existir) ─────
if [ ! -f "$CHLOG" ]; then
  {
    echo "# Changelog — camada personalizada do DeepSeek Harness (dsh-h-v1)"
    echo
    echo "Gerado e versionado automaticamente pelo auto-push/release."
    echo "Ordem cronológica — a versão mais recente fica no FIM do arquivo."
    echo
  } >"$CHLOG"
fi
{
  echo
  echo "## [$V] — $NOW (máquina $HOST)"
  echo "Release manual/estrutural — ${COMMIT_N:-0} commit(s) desde ${LAST_TAG:-o início}."
  printf '%s\n' "$COMMITS" | sed 's/^/  - /'
} >>"$CHLOG"
git -C "$CLONE" add "$CHLOG"

# ── Guard de segredos (o conteúdo do changelog é commitado) ─────
if ! ( cd "$CLONE" && "$SELF_DIR/guard-secrets.sh" --staged ); then
  echo "✋ release ABORTADO: guard detectou possível segredo no staged."
  git -C "$CLONE" reset -q -- "$CHLOG" 2>/dev/null || true
  git -C "$CLONE" checkout -- "$CHLOG" 2>/dev/null || true
  exit 1
fi

MSG="release: $V — ${COMMIT_N:-0} commit(s) desde ${LAST_TAG:-início}"
if ! git -C "$CLONE" commit -m "$MSG" --quiet; then
  echo "✋ release: falha no commit do CHANGELOG."
  git -C "$CLONE" reset -q -- "$CHLOG" 2>/dev/null || true
  git -C "$CLONE" checkout -- "$CHLOG" 2>/dev/null || true
  exit 1
fi
echo "✔ Commit: $MSG"

# ── Push (com rebase se outra máquina publicou antes) ──────────
PUSHED=0
for _ in 1 2 3; do
  if git -C "$CLONE" push --quiet 2>/dev/null; then PUSHED=1; break; fi
  echo "⚠  Push rejeitado (outra máquina?) — rebaseando e tentando de novo."
  if ! git -C "$CLONE" pull --rebase --quiet 2>/dev/null; then
    echo "✋ release: não foi possível rebasear após rejeição."
    exit 1
  fi
done
[ "$PUSHED" -eq 1 ] || { echo "✋ Push falhou após 3 tentativas (autenticação?)."; exit 1; }

# ── Tag da versão (âncora de rollback; nunca sobrescreve) ──────
for _ in 1 2 3; do
  VTAG="$(next_version)"
  if git -C "$CLONE" tag -a "$VTAG" -m "$MSG" 2>/dev/null \
     && git -C "$CLONE" push origin "$VTAG" --quiet 2>/dev/null; then
    echo "✔ Versão publicada: $VTAG (as máquinas recebem no próximo sync-pull)"
    exit 0
  fi
  echo "⚠  tag $VTAG já existia (outra máquina?) — tentando a próxima."
done
echo "⚠  Commit publicado, mas a tag automática não pôde ser criada agora."
exit 0
