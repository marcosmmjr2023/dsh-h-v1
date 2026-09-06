#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# auto-push.sh — PUBLICADOR ROTINEIRO (Linux/WSL) — via de MÃO DUPLA
# Rode em TODA máquina onde você edita o harness: recebe o que as outras
# publicaram e publica as suas edições da config viva (~/.dsh) sozinho.
#
# Cada publicação sobe DOCUMENTADA sobre a última versão:
#   • commit descritivo (arquivos alterados);
#   • versão automática vX.Y.Z (patch) com tag âncora;
#   • CHANGELOG.md do repo atualizado na mesma publicação.
#
# Ordem (robusta p/ várias máquinas):
#   1. espelha a config viva → overlay/ e COMMITA o espelho (árvore limpa);
#   2. integra o remoto (pull --rebase). Conflito = a versão DESTA máquina
#      (última a sincronizar) vira a versão atual; a outra fica preservada
#      no histórico/tag anterior — nunca --force, nunca perde versão;
#   3. calcula a próxima versão (após integrar), escreve o CHANGELOG e
#      commita a documentação;
#   4. push + tag da versão (nunca sobrescreve tag existente).
#
# Guardrails: flag <config viva>/.dsh-autoupdate.off desliga; flock contra
# concorrência; guard de segredos bloqueia commit suspeito (restaura espelho).
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
CHLOG="$CLONE/CHANGELOG.md"
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

HOST="$(hostname 2>/dev/null || echo "esta-maquina")"

# ── Restaura o espelho overlay/ ao HEAD (após bloqueio do guard) ─
restore_overlay() {
  git -C "$CLONE" reset -q -- "$MANAGED" 2>/dev/null || true
  git -C "$CLONE" checkout -- "$MANAGED" 2>/dev/null || true
  git -C "$CLONE" clean -qfd -- "$MANAGED" 2>/dev/null || true
}

# ── Guard de segredos (roda DENTRO do clone; o guard usa git diff) ─
guard_ok() { ( cd "$CLONE" && "$SELF_DIR/guard-secrets.sh" --staged ); }

# ── Integra o remoto; em conflito mantém a versão DESTA máquina ─
rebase_pull() {
  git -C "$CLONE" fetch -q origin || return 1
  # nada local para rebasear? fast-forward simples
  if git -C "$CLONE" merge-base --is-ancestor HEAD '@{u}' 2>/dev/null; then
    if git -C "$CLONE" merge --ff-only '@{u}' --quiet 2>/dev/null; then
      return 0
    fi
    echo "⚠  fast-forward falhou (há alterações não commitadas no clone?)"
    return 1
  fi
  # há commits locais: rebase
  if git -C "$CLONE" pull --rebase --quiet 2>/dev/null; then return 0; fi
  local n=0 resolved=0
  while [ -d "$CLONE/.git/rebase-merge" ] || [ -d "$CLONE/.git/rebase-apply" ]; do
    resolved=1
    n=$((n + 1))
    if [ "$n" -gt 10 ]; then
      echo "✋ rebase não converge; abortando (suas edições continuam na config viva)."
      git -C "$CLONE" rebase --abort >/dev/null 2>&1 || true
      return 1
    fi
    local f
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      echo "   ⚠ conflito em $f → mantida a versão DESTA máquina (a outra fica no histórico)"
      # num rebase, --theirs = o commit local sendo rebaseado (a versão desta máquina)
      git -C "$CLONE" checkout --theirs -- "$f" 2>/dev/null || true
      git -C "$CLONE" add -- "$f"
    done < <(git -C "$CLONE" diff --name-only --diff-filter=U)
    if ! GIT_EDITOR=true git -C "$CLONE" -c core.hooksPath=/dev/null rebase --continue >/dev/null 2>&1; then
      git -C "$CLONE" rebase --abort >/dev/null 2>&1 || true
      return 1
    fi
  done
  [ "$resolved" -eq 1 ] && return 0
  echo "⚠  pull --rebase falhou sem conflito (rede? árvore suja?) — veja: git -C \"$CLONE\" status"
  return 1
}

# ── Próxima versão vX.Y.Z (patch): maior tag v* + 1, ou manifest.json ─
bump_patch() {
  local v="$1" maj min pat
  v="${v#v}"
  IFS=. read -r maj min pat <<<"$v"
  echo "v${maj}.${min}.$((pat + 1))"
}

next_version() {
  local latest base
  latest="$(git -C "$CLONE" tag --list 'v[0-9]*' --sort=-version:refname 2>/dev/null | head -1 || true)"
  if [ -n "$latest" ]; then
    bump_patch "$latest"
    return 0
  fi
  base="$(grep -m1 '"version"' "$CLONE/manifest.json" 2>/dev/null \
    | sed -E 's/.*"version"[^0-9]*([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true)"
  [ -n "$base" ] || base="0.1.0"
  bump_patch "$base"
}

# ── Pré-visualização (não altera nada) ─────────────────────────
dry_run() {
  echo "▶ [dry-run] auto-push: $LIVE → $CLONE/overlay"
  git -C "$CLONE" fetch -q origin 2>/dev/null || true
  echo "── arquivos que seriam espelhados do live para o overlay ──"
  rsync -acn --exclude-from="$EXCL" --out-format='  %n' "$LIVE/" "$MANAGED/" \
    | sed '/^$/d' | grep -v '/$' | head -40
  local ahead
  ahead="$(git -C "$CLONE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
  echo "── commits locais ainda não enviados: ${ahead:-0} ──"
  if [ "${ahead:-0}" -gt 0 ]; then git -C "$CLONE" log --oneline "@{u}..HEAD"; fi
  echo "── próxima versão estimada: $(next_version) ──"
  echo "✔ [dry-run] nada foi alterado. Para publicar de verdade: tools/auto-push.sh"
  exit 0
}
[ "$MODE" = "--dry-run" ] && dry_run

echo "▶ auto-push: $LIVE → $CLONE/overlay (publicação rotineira, via de mão dupla)"

# 1) Espelha a config viva e COMMITA o espelho (árvore limpa p/ o rebase)
rsync -ac --exclude-from="$EXCL" "$LIVE/" "$MANAGED/"
git -C "$CLONE" add -A overlay
if ! guard_ok; then
  echo "✋ auto-push ABORTADO: guard detectou possível segredo no staged."
  echo "   Restaurando o espelho overlay/ ao HEAD (a config viva $LIVE não foi tocada;"
  echo "   corrija o arquivo lá e a próxima rodada tenta de novo)."
  restore_overlay
  exit 1
fi

git -C "$CLONE" fetch -q origin 2>/dev/null || true
AHEAD_N="$(git -C "$CLONE" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)"
FILES="$(git -C "$CLONE" diff --cached --name-only | sed 's#^overlay/##' || true)"
NFILES="$(printf '%s\n' "$FILES" | grep -cv '^$' || true)"
if git -C "$CLONE" diff --cached --quiet && [ "${AHEAD_N:-0}" -eq 0 ]; then
  echo "ℹ  Nada mudou — nada a publicar."
  exit 0
fi

PENDING="$(git -C "$CLONE" log --oneline '@{u}..HEAD' 2>/dev/null || true)"

# Commit 1: espelho da config viva (apenas se houver mudança de overlay)
if ! git -C "$CLONE" diff --cached --quiet; then
  if ! git -C "$CLONE" commit -m "sync(auto): espelho da config viva ($NFILES arquivo(s))" --quiet; then
    echo "✋ auto-push: falha ao commitar o espelho; restaurando."
    restore_overlay
    exit 1
  fi
fi

# 2) Integra o remoto (rebaseia o espelho + commits locais; conflito: local vence)
if ! rebase_pull; then
  echo "✋ auto-push ABORTADO: não foi possível integrar o remoto."
  echo "   Se o clone tem alterações manuais não commitadas (git -C \"$CLONE\" status),"
  echo "   commit-as ou publique com tools/sync-push.sh antes. Suas edições seguem na config viva."
  exit 1
fi

# 3) Documentação: versão (calculada APÓS integrar) + CHANGELOG + commit
V="$(next_version)"
NOW="$(date '+%Y-%m-%d %H:%M')"
{
  echo
  echo "## [$V] — $NOW (máquina $HOST)"
  echo "Publicação automática — última sincronização desta máquina."
  if [ "${NFILES:-0}" -gt 0 ]; then
    echo "- Arquivos alterados (${NFILES}):"
    printf '%s\n' "$FILES" | sed 's/^/  - /'
  fi
  if [ -n "$PENDING" ]; then
    echo "- Commits locais incorporados:"
    printf '%s\n' "$PENDING" | sed 's/^/  - /'
  fi
} >>"$CHLOG"
git -C "$CLONE" add "$CHLOG"
if ! guard_ok; then
  echo "✋ auto-push ABORTADO: guard no CHANGELOG/overlay. Restaurando."
  restore_overlay
  git -C "$CLONE" reset -q -- "$CHLOG" 2>/dev/null || true
  git -C "$CLONE" checkout -- "$CHLOG" 2>/dev/null || true
  exit 1
fi

if [ "${NFILES:-0}" -gt 0 ]; then
  SHORT="$(printf '%s\n' "$FILES" | head -4 | tr '\n' ',' | sed 's/,$//')"
  [ "${NFILES:-0}" -gt 4 ] && SHORT="${SHORT},+$((NFILES - 4)) arquivo(s)"
else
  SHORT="commits locais publicados"
fi
MSG="sync(auto): $V — $SHORT"
if ! git -C "$CLONE" commit -m "$MSG" --quiet; then
  echo "✋ auto-push: falha ao commitar a documentação ($V); restaurando."
  restore_overlay
  git -C "$CLONE" reset -q -- "$CHLOG" 2>/dev/null || true
  git -C "$CLONE" checkout -- "$CHLOG" 2>/dev/null || true
  exit 1
fi
echo "✔ Documentação commitada: $MSG"

# 4) Push (sem --force); rejeitado → rebaseia e tenta de novo
PUSHED=0
for _ in 1 2 3; do
  if git -C "$CLONE" push --quiet 2>/dev/null; then PUSHED=1; break; fi
  echo "⚠  Push rejeitado (outra máquina publicou antes?) — rebaseando e tentando de novo."
  if ! rebase_pull; then echo "✋ auto-push ABORTADO no push (ver mensagens acima)."; exit 1; fi
done
if [ "$PUSHED" -ne 1 ]; then
  echo "✋ Push falhou após 3 tentativas (autenticação?). Configure gh auth login ou um PAT."
  exit 1
fi

# 5) Tag da versão (nunca sobrescreve tag existente)
for _ in 1 2 3; do
  VTAG="$(next_version)"
  if git -C "$CLONE" tag -a "$VTAG" -m "$MSG" 2>/dev/null \
     && git -C "$CLONE" push origin "$VTAG" --quiet 2>/dev/null; then
    echo "✔ Versão publicada: $VTAG"
    exit 0
  fi
  echo "⚠  tag $VTAG já existia (outra máquina?) — tentando a próxima."
done
echo "⚠  Commit publicado, mas a tag automática não pôde ser criada agora."
echo "   A próxima rodada/publicação atribui a versão seguinte. Nada foi perdido."
exit 0
