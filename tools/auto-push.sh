#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# auto-push.sh — PUBLICADOR ROTINEIRO (máquina mestra)
# Sobe sozinho para o GitHub a camada personalizada nova: quando a
# config viva (~/.dsh) tem conteúdo diferente do overlay/ publicado,
# ou o clone tem commits locais ainda não enviados, ele espelha,
# comita e faz push — sem ação manual. As outras máquinas recebem a
# versão nova no próximo sync-pull delas.
#
# Guardrails (sempre):
#   • Se <config viva>/.dsh-autoupdate.off existir, sai sem fazer nada
#     (mesmo interruptor ON/OFF do painel que desliga o sync-pull).
#   • Integra remotas primeiro (pull --rebase). Nunca força push.
#   • Só publica o espelho overlay/ (nunca varre tools/, docs/ etc.).
#   • Guard de segredos bloqueia o commit se detectar credencial.
#   • Nunca cria tag (tags/versões são manuais — âncoras de rollback).
#   • Lock (flock) para não concorrer com sync-pull/sync-push manuais.
#
# Uso:  tools/auto-push.sh [--dry-run]
# Vars: DSH_CLONE (padrão: pasta pai de tools/), DSH_LIVE (padrão: ~/.dsh)
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLONE="${DSH_CLONE:-$(cd "$SELF_DIR/.." && pwd)}"
LIVE="${DSH_LIVE:-$HOME/.dsh}"
EXCL="$SELF_DIR/sync-excludes.txt"
MANAGED="$CLONE/overlay"
MODE="${1:-}"

[ -f "$EXCL" ] || { echo "ERRO: arquivo de exclusões ausente: $EXCL"; exit 1; }
[ -d "$CLONE/.git" ] || { echo "ERRO: $CLONE não é um clone git."; exit 1; }
[ -d "$LIVE" ] || { echo "ERRO: config viva $LIVE não existe."; exit 1; }

# ── Interruptor ON/OFF (mesmo do auto-update) ──────────────────
if [ -f "$LIVE/.dsh-autoupdate.off" ]; then
  echo "⏸ auto-push DESLIGADO (flag $LIVE/.dsh-autoupdate.off presente)"
  exit 0
fi

# ── Lock: nunca concorrer com outra sincronização no mesmo clone ─
LOCK="$CLONE/.git/dsh-autopush.lock"
exec 9>"$LOCK"
if ! flock -w 60 9; then
  echo "⏸ auto-push: outra sincronização em andamento (lock $LOCK) — pulando esta rodada."
  exit 0
fi

# ── Restaura o espelho overlay/ ao HEAD (após bloqueio do guard) ─
# `git reset --hard -- <path>` não existe no git; equivalente clássico:
restore_overlay() {
  git -C "$CLONE" reset -q -- "$MANAGED" 2>/dev/null || true
  git -C "$CLONE" checkout -- "$MANAGED" 2>/dev/null || true
  git -C "$CLONE" clean -qfd -- "$MANAGED" 2>/dev/null || true
}

# ── Pré-visualização (não altera nada) ─────────────────────────
dry_run() {
  echo "▶ [dry-run] auto-push: $LIVE → $CLONE/overlay"
  echo "── arquivos que seriam espelhados do live para o overlay ──"
  rsync -acn --exclude-from="$EXCL" --out-format='  %n' "$LIVE/" "$MANAGED/" | sed '/^$/d' | head -50
  local ahead
  ahead="$(git -C "$CLONE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  echo "── commits locais ainda não enviados: $ahead ──"
  if [ "$ahead" -gt 0 ]; then git -C "$CLONE" log --oneline "@{u}..HEAD"; fi
  echo "✔ [dry-run] nada foi alterado. Para publicar de verdade: tools/auto-push.sh"
  exit 0
}
[ "$MODE" = "--dry-run" ] && dry_run

echo "▶ auto-push: $LIVE → $CLONE/overlay (publicação rotineira)"

# ── Integra mudanças remotas antes de publicar as suas ─────────
if ! git -C "$CLONE" pull --rebase --quiet; then
  echo "⚠  pull --rebase não limpo (alterações locais no clone?); seguindo com o que há."
fi

# ── Espelha a config viva sobre o espelho do clone ─────────────
rsync -ac --exclude-from="$EXCL" "$LIVE/" "$MANAGED/"
git -C "$CLONE" add -A overlay

# ── Guard: bloqueia se algo parecido com credencial entrou ─────
# Roda DENTRO do clone (o guard usa git diff sem -C; o cron chama
# este script de fora do repositório, ex.: a partir de $HOME).
if ! ( cd "$CLONE" && "$SELF_DIR/guard-secrets.sh" --staged ); then
  echo "✋ auto-push ABORTADO: guard detectou possível segredo no staged."
  echo "   Restaurando o espelho overlay/ ao HEAD (a config viva $LIVE não foi tocada;"
  echo "   corrija o arquivo lá e a próxima rodada tenta de novo)."
  restore_overlay
  exit 1
fi

AHEAD="$(git -C "$CLONE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
if git -C "$CLONE" diff --cached --quiet && [ "$AHEAD" -eq 0 ]; then
  echo "ℹ  Nada mudou — nada a publicar."
  exit 0
fi

# ── Commit automático SÓ do espelho overlay/ (se houver mudança) ─
if ! git -C "$CLONE" diff --cached --quiet; then
  MSG="sync(auto): publicação automática da camada — $(date '+%Y-%m-%d %H:%M')"
  if ! git -C "$CLONE" commit -m "$MSG" --quiet; then
    echo "✋ auto-push: commit falhou (guard no hook?); restaurando espelho overlay/ ao HEAD."
    restore_overlay
    exit 1
  fi
  echo "✔ Commit automático: $MSG"
fi

# ── Push simples (nunca --force) ───────────────────────────────
if ! git -C "$CLONE" push --quiet; then
  echo "✋ Push falhou (autenticação?). Configure: gh auth login  ou  um PAT no credential helper."
  exit 1
fi
echo "✔ auto-push concluído: versão local publicada no GitHub (outras máquinas recebem no próximo sync-pull)."
