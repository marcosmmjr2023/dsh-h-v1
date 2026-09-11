#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# piai-meta-patch.sh — registra "meta" no catalogo nativo do pi-ai
#
# A pagina Configuracoes > Modelos mostra os provedores "padrao" vindos do
# catalogo compilado do pacote @earendil-works/pi-ai (models.generated.js).
# Um provider declarado so em settings.yaml (llm-pi-ai.providers.meta) entra
# na lista, mas com selo "Custom". Este patch insere a rota "meta" nesse
# catalogo (MODELS) para o Harness tratar a Meta como provider padrao.
#
# Uso:
#   tools/piai-meta-patch.sh            # aplica (pede sudo se preciso)
#   tools/piai-meta-patch.sh --remove   # desfaz (restaura o .dshbak)
#   tools/piai-meta-patch.sh --auto     # aplica SEM prompt (cron/CI); se nao
#                                       # tiver sudo silencioso, apenas avisa.
#
# Idempotente: roda de novo sem efeito. Precisa ser reaplicado apos qualquer
# reinstall do core (npm update -g @deepseek-ai/dsh), porque o npm regenera
# o models.generated.js. O sync-pull tenta aplicar automaticamente; quando nao
# ha sudo disponivel ele deixa um aviso para rodar este script manualmente.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

MODE="${1:-install}"

# Localiza o arquivo REAL do catalogo (o do profile e symlink para o core)
NPMROOT="$(npm root -g 2>/dev/null || true)"
FILE=""
# Lista em ARRAY, iterada com "${CANDS[@]}": com o glob entre aspas direto
# no `for` o shellcheck acusa SC2066 (severidade ERROR, entao -S warning nao
# filtra) e o CI cai. Aqui o caminho tambem NAO deve sofrer word splitting.
CANDS=(
  "$NPMROOT/@deepseek-ai/dsh/node_modules/@earendil-works/pi-ai/dist/models.generated.js"
)
for cand in "${CANDS[@]}"; do
  if [ -n "$cand" ] && [ -f "$cand" ]; then FILE="$(readlink -f "$cand")"; break; fi
done
if [ -z "$FILE" ]; then
  # fallback: procura no node_modules global
  FOUND="$(find "$NPMROOT" -path '*/@earendil-works/pi-ai/dist/models.generated.js' -print 2>/dev/null | head -n1 || true)"
  if [ -n "$FOUND" ]; then FILE="$(readlink -f "$FOUND")"; fi
fi
if [ -z "$FILE" ]; then
  echo "X nao achei models.generated.js do pi-ai (npm root -g: $NPMROOT)"
  exit 1
fi
echo "pi-ai catalog: $FILE"

# Eleva para sudo se o arquivo nao for gravavel (core instalado como root)
if [ ! -w "$FILE" ] && [ "$(id -u)" -ne 0 ]; then
  if [ "$MODE" = "--auto" ]; then
    if ! sudo -n true 2>/dev/null; then
      echo "! sem sudo silencioso para gravar no core. Rode manualmente:"
      echo "  sudo tools/piai-meta-patch.sh"
      exit 0
    fi
  fi
  exec sudo -E bash "$0" "$MODE"
fi

if [ "$MODE" = "--remove" ]; then
  if [ -f "$FILE.dshbak" ]; then
    cp "$FILE.dshbak" "$FILE"
    echo "ok: restaurado backup ($FILE.dshbak)"
  else
    node -e '
      const fs=require("fs");
      const f=process.argv[1];
      let s=fs.readFileSync(f,"utf8");
      s=s.replace(/^    "meta": \{\},\n/m,"");
      fs.writeFileSync(f,s);
    ' "$FILE"
    echo "ok: rota \"meta\" removida do catalogo"
  fi
  exit 0
fi

# Aplica (idempotente), com backup unico
if grep -q '"meta": {}' "$FILE"; then
  echo "ok: catalogo ja contem \"meta\" (nada a fazer)"
  exit 0
fi
if [ ! -f "$FILE.dshbak" ]; then
  cp "$FILE" "$FILE.dshbak"
  echo "backup criado: $FILE.dshbak"
fi
node -e '
  const fs=require("fs");
  const f=process.argv[1];
  let s=fs.readFileSync(f,"utf8");
  if (!s.includes("\"meta\": {}")) {
    const needle="\"openrouter\": OPENROUTER_MODELS,";
    if (!s.includes(needle)) throw new Error("ponto de insercao nao encontrado no catalogo");
    s=s.replace(needle, needle + "\n    \"meta\": {},");
    fs.writeFileSync(f,s);
    console.log("ok: rota \"meta\" registrada no catalogo do pi-ai (reinicie o dsh para aplicar)");
  } else {
    console.log("ok: ja continha \"meta\"");
  }
' "$FILE"
