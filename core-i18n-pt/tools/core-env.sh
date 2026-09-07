#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# core-env.sh — AMBIENTES PARALELOS do harness (A/B test de core)
# Cada ambiente é um "sistema inteiro novo" isolado: pasta própria com core
# npm + home copiado (config/plugins/credenciais), porta própria e atalho
# próprio — o sistema atual fica INTACTO até você promover o novo.
#
# Duplo versionamento: v<versão-do-sistema> (repo, ex.: v0.2.11) +
#                       c<versão-do-core>  (ex.: c0.1.2-rc.1)
#
# Uso:
#   core-env.sh list
#   core-env.sh create <nome> --core <versão> [--port <p>] [--from <home|v1|v2>]
#   core-env.sh status <nome> | start <nome> | stop <nome> | remove <nome>
#   core-env.sh promote <nome>      → mostra o comando para tornar o testado o padrão
#
# Ambientes ficam em ~/.dsh-envs/<nome>/ (nunca sincronizado). Rode como deploy.
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$SELF_DIR/../.." && pwd)"
BASE="${DSH_ENVS_ROOT:-/home/deploy/.dsh-envs}"
NODE_BIN="$(command -v node)"
SOURCE_HOME="/home/deploy/.dsh-v2"
SYSTEM_VER="$(git -C /home/deploy/dsh-v2 describe --tags --abbrev=0 2>/dev/null || echo dev)"

usage() { sed -n '3,16p' "$0" | sed 's/^# \{0,1\}//'; }
port_free() { # porta candidata
  local p="$1"
  while ss -ltn 2>/dev/null | grep -q ":${p} "; do p=$((p + 1)); done
  echo "$p"
}

cmd="${1:-list}"
case "$cmd" in
  list)
    for m in "$BASE"/*/meta.json; do
      [ -f "$m" ] || continue
      node -e 'const m=require(process.argv[1]);console.log(`${m.name.padEnd(16)} port=${m.port} core=${m.core} sys=${m.sys} ${m.url}`)' "$m"
    done
    [ -z "$(ls -d "$BASE"/*/meta.json 2>/dev/null)" ] && echo "nenhum ambiente ainda (core-env.sh create <nome> --core <versão>)"
    ;;
  status)
    name="${2:-}"; [ -n "$name" ] || { echo "informe o nome"; exit 2; }
    m="$BASE/$name/meta.json"; [ -f "$m" ] || { echo "ambiente '$name' não existe"; exit 1; }
    node -e 'const m=require(process.argv[1]);console.log(JSON.stringify(m,null,1))' "$m"
    /usr/bin/pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);p=[x for x in d if x['name']=='dsh-env-$name'];print('pm2:', p[0]['pm2_env']['status'] if p else 'parado')"
    ;;
  create)
    name="${2:-}"; [ -n "$name" ] || { echo "uso: core-env.sh create <nome> --core <versão> [--port p] [--from v1|v2]"; exit 2; }
    ver=""; port=""; from="$SOURCE_HOME"
    while [ "$#" -gt 2 ]; do
      case "$3" in
        --core) ver="${4:-}"; shift 2 ;;
        --port) port="${4:-}"; shift 2 ;;
        --from) from="${4:-/home/deploy/.dsh}"; shift 2 ;;
        *) shift ;;
      esac
    done
    [ -n "$ver" ] || { echo "ERRO: informe --core <versão>"; exit 2; }
    case "$ver" in *[!0-9A-Za-z._-]*|"") echo "ERRO: versão inválida"; exit 2 ;; esac
    envdir="$BASE/$name"
    [ -e "$envdir" ] && { echo "✋ ambiente '$name' já existe (core-env.sh remove $name)"; exit 1; }
    [ -z "$port" ] && port="$(port_free 3110)"
    mkdir -p "$envdir/core" "$envdir/home"
    echo "▶ criando ambiente '$name' → core c$ver | porta $port | sistema $SYSTEM_VER"
    echo "   (o sistema atual em ~/.dsh-v2 e /opt fica INTACTO)"
    # 1) home copiado (sem sessões/storages/node_modules/logs)
    rsync -a --exclude sessions --exclude storages --exclude '*.log' --exclude node_modules \
      "$from/" "$envdir/home/" 2>/dev/null || cp -a "$from/." "$envdir/home/"
    rm -rf "$envdir/home/profiles/node_modules"
    # 2) core isolado no ambiente
    if ! npm install -g --prefix "$envdir/core" "@deepseek-ai/dsh@$ver" >"$envdir/install.log" 2>&1; then
      echo "✋ falha ao instalar core no ambiente:"; tail -5 "$envdir/install.log"; rm -rf "$envdir"; exit 1
    fi
    coreRoot="$(npm root -g --prefix "$envdir/core" 2>/dev/null)"
    # 3) patches pt-BR no core do ambiente
    if DSH_CORE_PKGS="$coreRoot/@deepseek-ai" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --force >/dev/null 2>&1; then
      echo "  ✔ pt-BR aplicado no core do ambiente"
    else
      echo "  ⚠ pt-BR não aplicou limpo no ambiente (contexto?) — siga mesmo assim para teste."
    fi
    # 4) perfis → deps do próprio ambiente (isolado do core antigo)
    mkdir -p "$envdir/home/profiles/node_modules/@deepseek-ai"
    for pkg in "$coreRoot"/@deepseek-ai/*; do
      [ -d "$pkg" ] && ln -s "$pkg" "$envdir/home/profiles/node_modules/@deepseek-ai/$(basename "$pkg")" 2>/dev/null
    done
    # 5) meta + atalho
    cat > "$envdir/meta.json" <<JSON
{"name":"$name","core":"$ver","sys":"$SYSTEM_VER","port":$port,"url":"http://127.0.0.1:$port","home":"$envdir/home","coreRoot":"$coreRoot","created":"$(date -Is)"}
JSON
    cat > "$envdir/start.sh" <<EOF
#!/usr/bin/env bash
# Atalho do ambiente '$name' — sistema $SYSTEM_VER · core c$ver
echo "Abrindo $SYSTEM_VER · c$ver → http://127.0.0.1:$port"
cd /home/deploy || exit 1
DSH_ENV_NAME="$name" DSH_CORE_VERSION="$ver" DSH_HOME="$envdir/home" DSH_WEB_URL="http://127.0.0.1:$port" \
  $NODE_BIN "$coreRoot/@deepseek-ai/dsh/lib/bin.js" --profile web --no-open --port "$port" --host 127.0.0.1
EOF
    chmod +x "$envdir/start.sh"
    # 6) sobe via pm2 (paralelo, não mexe no atual)
    cd /home/deploy || exit 1
    DSH_ENV_NAME="$name" DSH_CORE_VERSION="$ver" DSH_HOME="$envdir/home" DSH_WEB_URL="http://127.0.0.1:$port" \
      /usr/bin/pm2 start "$NODE_BIN" --name "dsh-env-$name" -- "$coreRoot/@deepseek-ai/dsh/lib/bin.js" \
        --profile web --no-open --port "$port" --host 127.0.0.1 >/dev/null 2>&1
    echo "▶ aguardando ambiente responder…"
    for i in $(seq 1 40); do
      code=$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$port/" 2>/dev/null || true)
      if [ "$code" = "200" ]; then echo "✔ '$name' no ar: $SYSTEM_VER · c$ver → http://127.0.0.1:$port"; break; fi
      if [ "$code" = "401" ]; then
        tok="$(/usr/bin/pm2 logs "dsh-env-$name" --nostream --lines 50 2>/dev/null | grep -oE '\?token=[A-Za-z0-9_-]+' | tail -1)"
        echo "ℹ '$name' pede autenticação: http://127.0.0.1:$port/${tok#?}" 2>/dev/null || echo "ℹ '$name' pede token — veja: pm2 logs dsh-env-$name"
        break
      fi
      sleep 2
    done
    [ "$code" = "200" ] || echo "⚠ não respondeu 200 ainda — veja: pm2 logs dsh-env-$name / $envdir"
    echo "Ambiente pronto em $envdir  (atalho: $envdir/start.sh)"
    ;;
  start|stop|remove)
    name="${2:-}"; m="$BASE/$name/meta.json"
    [ -f "$m" ] || { echo "ambiente '$name' não existe"; exit 1; }
    case "$cmd" in
      start) /usr/bin/pm2 start "dsh-env-$name" >/dev/null 2>&1 && echo "✔ iniciado (URL no meta.json)";;
      stop) /usr/bin/pm2 stop "dsh-env-$name" >/dev/null 2>&1 && echo "✔ parado (ambiente preservado)";;
      remove)
        /usr/bin/pm2 delete "dsh-env-$name" >/dev/null 2>&1 || true
        rm -rf "$BASE/$name"; echo "✔ ambiente '$name' removido";;
    esac
    ;;
  promote)
    name="${2:-}"; m="$BASE/$name/meta.json"
    [ -f "$m" ] || { echo "ambiente '$name' não existe"; exit 1; }
    ver="$(node -e 'console.log(require(process.argv[1]).core)' "$m")"
    echo "Para tornar '$name' (c$ver, testado) o sistema padrão, aplique o core validado nos prefixos canônicos:"
    echo "  sudo $REPO/core-i18n-pt/tools/core-update.sh --skip-preview --install $ver"
    echo "Depois reinicie a GUI (botão '▶ Reiniciar agora' no painel). O ambiente pode ser removido:"
    echo "  core-env.sh remove $name"
    ;;
  -h|--help) usage ;;
  *) echo "opção desconhecida: $1"; usage; exit 2 ;;
esac
