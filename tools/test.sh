#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# test.sh — testes funcionais do sistema de sync/rollback
# Roda cenários em diretórios temporários (nunca toca ~/.dsh real) e usa
# um "remote" git local (bare) para testar push/pull sem rede.
# Saída: 0 = tudo OK | 1 = falhas (lista no final).
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
declare -a FAILURES

ok()   { PASS=$((PASS + 1)); echo "  ✔ $1"; }
fail() { FAIL=$((FAIL + 1)); FAILURES+=("$1"); echo "  ✋ FALHA: $1"; }

check() { # check <desc> <cmd...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi
}

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
export DSH_SNAP_ROOT="$T/snaps"

git config --global user.name "test" 2>/dev/null
git config --global user.email "test@example.com" 2>/dev/null

# ── monta remote com overlay inicial ──────────────────────────
REMOTE="$T/remote.git"; WORK="$T/work"
git init -q --bare -b main "$REMOTE"
git clone -q "$REMOTE" "$WORK"
mkdir -p "$WORK/overlay/profiles/web"
printf 'model: v1\n' > "$WORK/overlay/settings.yaml"
printf '%s\n' '- id: p1' "  name: '__DSH_HOME__/smart-router-plugin.js'" > "$WORK/overlay/cordis.patch.yml.tpl"
printf '%s\n' '[]' > "$WORK/overlay/profiles/web/cordis.patch.yml"
git -C "$WORK" add -A; git -C "$WORK" commit -qm "v1"; git -C "$WORK" tag v1.0.0
git -C "$WORK" push -q origin main --tags

CLONE="$T/clone"; LIVE="$T/live"
git clone -q "$REMOTE" "$CLONE"
mkdir -p "$LIVE/sessions" "$LIVE/storages"
printf 'segredo\n' > "$LIVE/.credentials.yaml"
printf 'estado\n'   > "$LIVE/sessions/s1.json"
printf 'local-antigo\n' > "$LIVE/settings.yaml"
export DSH_CLONE="$CLONE" DSH_LIVE="$LIVE"

echo "── Guard (bloqueio de segredos)"
printf '%s\n' 'key="sk-proj-ABCDEFGHIJ1234567890abcdefgh"' > "$T/bad.txt"
if "$REPO_DIR/tools/guard-secrets.sh" "$T/bad.txt" >/dev/null 2>&1; then
  fail "guard deveria bloquear arquivo com chave sk-"
else ok "guard bloqueia chave sk-"; fi
printf '%s\n' 'model: deepseek-v4-flash' > "$T/good.txt"
"$REPO_DIR/tools/guard-secrets.sh" "$T/good.txt" >/dev/null 2>&1 \
  && ok "guard libera conteúdo limpo" || fail "guard deveria liberar conteúdo limpo"

echo "── sync-pull (aplica overlay, exclui segredos, gera cordis.patch)"
"$REPO_DIR/tools/sync-pull.sh" >/dev/null 2>&1
grep -q 'model: v1' "$LIVE/settings.yaml"           && ok "pull atualizou settings.yaml"    || fail "pull não atualizou settings.yaml"
[ -f "$LIVE/.credentials.yaml" ]                    && ok "credencial local preservada"    || fail "pull apagou credencial local!"
[ -d "$LIVE/sessions" ]                             && ok "sessions local preservado"      || fail "pull apagou sessions local!"
grep -q "__DSH_HOME__" "$LIVE/cordis.patch.yml"     && fail "patch gerado ainda tem placeholder" || ok "patch gerado sem placeholder"
grep -q "$LIVE" "$LIVE/cordis.patch.yml"            && ok "patch gerado aponta p/ config viva desta máquina" || fail "patch gerado não aponta p/ esta máquina"
[ ! -f "$LIVE/cordis.patch.yml.tpl" ]               && ok "template não vaza p/ config viva" || fail "template foi copiado p/ config viva"

echo "── sync-push (publica edições locais, NUNCA segredos nem patch gerado)"
printf 'model: v2-local\n' > "$LIVE/settings.yaml"
printf 'novo\n' > "$LIVE/plugin-novo.js"
printf 'outro-segredo\n' >> "$LIVE/.credentials.yaml"
"$REPO_DIR/tools/sync-push.sh" "teste push" >/dev/null 2>&1
git -C "$CLONE" ls-files --error-unmatch overlay/plugin-novo.js >/dev/null 2>&1 \
  && ok "plugin novo publicado" || fail "plugin novo não foi publicado"
git -C "$CLONE" ls-files --error-unmatch overlay/cordis.patch.yml >/dev/null 2>&1 \
  && fail "cordis.patch.yml gerado entrou no repo!" || ok "patch gerado não entra no repo"
git -C "$CLONE" ls-files | grep -q '.credentials.yaml' \
  && fail "credencial entrou no repo!" || ok "credencial não entra no repo"

echo "── snapshot (unicidade, list, prune, restore)"
printf 'v2\n' > "$LIVE/settings.yaml"
"$REPO_DIR/tools/snapshot.sh" create >/dev/null 2>&1 && ok "snapshot 1 criado" || fail "snapshot 1 falhou"
printf 'v3\n' > "$LIVE/settings.yaml"
"$REPO_DIR/tools/snapshot.sh" create >/dev/null 2>&1 && ok "snapshot 2 criado (nome único)" || fail "snapshot 2 falhou"
n="$(find "$DSH_SNAP_ROOT" -maxdepth 1 -type d -name 'snap-*' | wc -l)"
[ "$n" -ge 2 ] && ok "2+ snapshots existem" || fail "esperava 2 snapshots, achei $n"

echo "── rollback p/ tag (restaura conteúdo, remove arquivos novos, preserva locais)"
printf 'feature-nova\n' > "$LIVE/profiles-extra-remove-este.js"  # simula arquivo q versão nova traria
# simulando: versão nova adicionou arquivo no overlay? criamos commit v2 no CLONE? use repo remoto:
# cria v2 no work e puxa (rollback será para v1.0.0)
# WORK está atrás (CLONE já fez push de teste): integra antes de publicar v2
git -C "$WORK" pull -q --rebase origin main
printf 'model: v2-remote\n' > "$WORK/overlay/settings.yaml"
printf '%s\n' 'novo-arquivo' > "$WORK/overlay/arq-v2.js"
git -C "$WORK" add -A; git -C "$WORK" commit -qm "v2"; git -C "$WORK" push -q origin main --tags
"$REPO_DIR/tools/sync-pull.sh" >/dev/null 2>&1
[ -f "$LIVE/arq-v2.js" ] && ok "v2 aplicada via pull" || fail "pull não aplicou v2"
# plugin-novo.js foi PUBLICADO na v2 (rastreado) → rollback p/ v1.0.0 pode removê-lo.
# somente-local.js nunca foi publicado → rollback DEVE preservá-lo.
printf '%s\n' 'so-local' > "$LIVE/somente-local.js"
"$REPO_DIR/tools/rollback.sh" v1.0.0 >/dev/null 2>&1
grep -q 'model: v1' "$LIVE/settings.yaml"  && ok "rollback restaurou settings v1"  || fail "rollback não restaurou settings v1"
[ ! -f "$LIVE/arq-v2.js" ]                && ok "rollback removeu arquivo da v2"   || fail "rollback não removeu arq-v2.js"
[ -f "$LIVE/somente-local.js" ]           && ok "arquivo só-local preservado"       || fail "rollback apagou arquivo só-local"
grep -q "$LIVE" "$LIVE/cordis.patch.yml"  && ok "rollback regenerou patch p/ esta máquina" || fail "rollback não regenerou patch"

echo "── restore de snapshot (volta ao estado pré-quebra)"
# âncora explícita: estado bom → snapshot → quebra → restore
printf 'model: v2-local\n' > "$LIVE/settings.yaml"
"$REPO_DIR/tools/snapshot.sh" create >/dev/null 2>&1
GOOD_SNAP="$(find "$DSH_SNAP_ROOT" -maxdepth 1 -type d -name 'snap-*' -printf '%f\n' | sort -r | head -1)"
printf 'quebrado\n' > "$LIVE/settings.yaml"
"$REPO_DIR/tools/rollback.sh" --snapshot "$GOOD_SNAP" >/dev/null 2>&1
grep -q 'model: v2-local' "$LIVE/settings.yaml" && ok "snapshot restaurou estado bom" || fail "snapshot restore falhou (estado: $(cat "$LIVE/settings.yaml" 2>/dev/null))"

echo
echo "════ RESUMO: $PASS OK, $FAIL falhas ════"
if [ "$FAIL" -gt 0 ]; then
  printf '  - %s\n' "${FAILURES[@]}"
  exit 1
fi
exit 0
