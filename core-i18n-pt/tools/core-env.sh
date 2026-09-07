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
# ── Alocador de portas com FAIXA + verificação de conflitos ────────────
# Range configurável (DSH_PORT_RANGE_START/END) e portas reservadas
# (DSH_RESERVED_PORTS). Evita conflito com: serviços escutando (ss),
# portas reservadas (3000/3001/3002 FreeLLMAPI, 3080/3081 GUIs, etc.) e
# portas já usadas por outros ambientes (~/.dsh-envs/*/meta.json).
PORT_RANGE_START="${DSH_PORT_RANGE_START:-3110}"
PORT_RANGE_END="${DSH_PORT_RANGE_END:-3900}"
RESERVED_PORTS="${DSH_RESERVED_PORTS:-3000,3001,3002,3003,3080,3081,8125}"
alloc_env_port() {
  local p
  for ((p=PORT_RANGE_START; p<=PORT_RANGE_END; p++)); do
    case ",$RESERVED_PORTS," in *",$p,"*) continue;; esac
    ss -ltn 2>/dev/null | grep -q ":$p " && continue
    if grep -rlE "\"port\": ?$p[,}]" "$BASE"/*/meta.json 2>/dev/null | grep -q .; then continue; fi
    echo "$p"
    return 0
  done
  echo "0"
}
free_ports_help() {
  echo "  faixa alocável: $PORT_RANGE_START–$PORT_RANGE_END (env DSH_PORT_RANGE_START/END)"
  echo "  reservadas: $RESERVED_PORTS (env DSH_RESERVED_PORTS)"
}


# ── atalho X11 (menu): wrapper + .desktop por ambiente
deps_root() { # node_modules-root -> dir @deepseek-ai que contém dsh-client-locale (aninhado ou plano)
  local r="$1"
  if [ -d "$r/@deepseek-ai/dsh/node_modules/@deepseek-ai/dsh-client-locale" ]; then
    echo "$r/@deepseek-ai/dsh/node_modules/@deepseek-ai"
  elif [ -d "$r/@deepseek-ai/dsh-client-locale" ]; then
    echo "$r/@deepseek-ai"
  else
    echo "$r/@deepseek-ai"
  fi
}

# ── teste de sanidade do ambiente (primeiro uso) ────────────────────────
sanity_test() {
  local name="$1" m="$BASE/$name/meta.json" fails=0
  [ -f "$m" ] || { echo "✋ ambiente '$name' não existe"; return 1; }
  local port core sys url
  port="$(node -e 'console.log(require(process.argv[1]).port)' "$m")"
  core="$(node -e 'console.log(require(process.argv[1]).core)' "$m")"
  sys="$(node -e 'console.log(require(process.argv[1]).sys)' "$m")"
  url="http://127.0.0.1:$port"
  echo "=== teste de sanidade: $name ($sys · c$core) → $url ==="
  local st ok=""
  st=$(/usr/bin/pm2 jlist 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);p=[x for x in d if x['name']=='dsh-env-$name'];print(p[0]['pm2_env']['status'] if p else 'down')")
  if [ "$st" = "online" ]; then echo "  ✔ servidor pm2: online"; else echo "  ✋ servidor pm2: $st"; fails=$((fails+1)); fi
  local code; code=$(curl -s -o /dev/null -w '%{http_code}' "$url/" 2>/dev/null || echo down)
  if [ "$code" = 200 ] || [ "$code" = 401 ]; then echo "  ✔ página responde (http=$code — token quando 401)"; else echo "  ✋ página sem resposta (http=$code)"; fails=$((fails+1)); fi

  local log; log="/home/deploy/.pm2/logs/dsh-env-$name-out.log"
  local errs; errs=$(grep -icE 'failed to import|load entry|SyntaxError|Unexpected token' "$log" 2>/dev/null || true); errs=${errs:-0}
  if [ "$errs" -eq 0 ] 2>/dev/null; then echo "  ✔ sem erros de importação/sintaxe"; else echo "  ✋ erros de importação: ${errs:-?}"; fails=$((fails+1)); fi
  local dep; dep="$BASE/$name/core/lib/node_modules/@deepseek-ai/dsh/node_modules/@deepseek-ai"
  local ptc; ptc=$(grep -c Português "$dep/dsh-client-locale/lib/client.js" 2>/dev/null || echo 0)
  if [ "$ptc" -ge 1 ]; then echo "  ✔ pt-BR presente (Português)"; else echo "  ✋ pt-BR ausente"; fails=$((fails+1)); fi
  for marker in '\[VersionBadge\]' '\[LayoutPanel\]' '\[FreeLLMAPI-Shortcut\]'; do
    grep -q "$marker" "$log" 2>/dev/null && echo "  ✔ plugin $marker carregou" || { echo "  ✋ plugin $marker não carregou"; fails=$((fails+1)); }
  done
  local ping; ping=$(curl -fsS --max-time 3 http://127.0.0.1:3002/api/ping -o /dev/null -w '%{http_code}' 2>/dev/null || echo down)
  if [ "$ping" = 200 ]; then echo "  ✔ FreeLLMAPI (3002) ping 200"; else echo "  ✋ FreeLLMAPI ping: $ping"; fails=$((fails+1)); fi
  local cors; cors=$(curl -s -i -H "Origin: $url" http://127.0.0.1:3002/api/ping 2>/dev/null | grep -i '^access-control-allow-origin' | tr -d '
')
  case "$cors" in *"$url"*) echo "  ✔ CORS FreeLLMAPI libera $url";; *) echo "  ✋ CORS FreeLLMAPI sem $url"; fails=$((fails+1));; esac
  ls -d /home/deploy/.dsh-core-backups/core-* >/dev/null 2>&1 && echo "  ✔ backup de segurança existe" || { echo "  ✋ sem backup (core-backup.sh)"; fails=$((fails+1)); }
  if [ "$fails" -eq 0 ]; then echo "✔ APROVADO — pode promover/commitar/publicar."; else echo "✋ $fails falha(s) — corrija antes de promover."; fi
  return $fails
}

write_launcher() {
  local name="$1" m="$BASE/$name/meta.json"
  [ -f "$m" ] || { echo "ambiente '$name' não existe"; return 1; }
  local core sys port url
  core="$(node -e 'console.log(require(process.argv[1]).core)' "$m")"
  sys="$(node -e 'console.log(require(process.argv[1]).sys)' "$m")"
  port="$(node -e 'console.log(require(process.argv[1]).port)' "$m")"
  url="http://127.0.0.1:$port"
  local datept; datept="$(node -e 'try{console.log((process.argv[1]||"").slice(0,10))}catch{}' "$(node -e 'console.log(require(process.argv[1]).created)' "$m")")"
  local tagline="$sys · c$core (novo core · ${datept:-data})"
  local wrapper="$BASE/$name/launch-gui.sh"
  cat > "$wrapper" <<'TPL'
#!/usr/bin/env bash
# Abre a GUI do ambiente @NAME@ — @TAGLINE@.
# Garante o servidor do FreeLLMAPI (dashboard :3002) e usa a URL real do
# boot (alguns cores exigem ?token).
curl -fsS --max-time 2 http://127.0.0.1:3002/api/ping >/dev/null 2>&1 || \
  (cd /home/deploy/projects/freellmapi && pm2 start server/dist/index.js --name freellmapi >/dev/null 2>&1 || pm2 restart freellmapi >/dev/null 2>&1)
pm2 describe dsh-env-@NAME@ >/dev/null 2>&1 || \
  (cd /home/deploy && DSH_ENV_NAME="@NAME@" DSH_CORE_VERSION="@CORE@" DSH_HOME="@HOME@" \
   DSH_WEB_URL="@URL@" pm2 start @NODEBIN@ --name "dsh-env-@NAME@" -- \
   "@BIN@" --profile web --no-open --port @PORT@ --host 127.0.0.1)
pm2 list 2>/dev/null | grep -q "dsh-env-@NAME@.*online" || pm2 restart "dsh-env-@NAME@" >/dev/null 2>&1
sleep 2
FULL="$(pm2 logs "dsh-env-@NAME@" --nostream --lines 200 2>/dev/null | grep -oE "http[^ ]*:@PORT@[^ ]*" | tail -1)"
[ -n "$FULL" ] || FULL="@URL@"
exec /opt/google/chrome/chrome --app="$FULL" --user-data-dir="/home/deploy/.config/dsh-env-@NAME@" --no-first-run --no-default-browser-check
TPL
  sed -e "s|@NAME@|$name|g" -e "s|@TAGLINE@|$tagline|g" -e "s|@SYS@|$sys|g" -e "s|@CORE@|$core|g"       -e "s|@PORT@|$port|g" -e "s|@URL@|$url|g" -e "s|@HOME@|$BASE/$name/home|g"       -e "s|@BIN@|$BASE/$name/core/lib/node_modules/@deepseek-ai/dsh/lib/bin.js|g"       -e "s|@NODEBIN@|$(command -v node)|g" "$wrapper" > "$wrapper.tmp" && mv "$wrapper.tmp" "$wrapper"
  chmod +x "$wrapper"
  mkdir -p /home/deploy/.local/share/applications
  local desk="/home/deploy/.local/share/applications/dsh-env-$name.desktop"
  cat > "$desk" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=DeepSeek Harness $name — c$core (novo · ${datept:-data})
Comment=Abre o ambiente paralelo '$name' ($sys · c$core) — porta $port (sistema atual intacto)
Exec=$wrapper
Icon=/opt/google/chrome/product_logo_256.png
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=false
EOF
  chmod 644 "$desk"
  desktop-file-validate "$desk" >/dev/null 2>&1 && echo "✔ atalho X11 criado: $desk"
  echo "   (no menu: 'DeepSeek Harness $name — c$core (novo · ${datept:-data})')"
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
    [ -z "$port" ] && { port="$(alloc_env_port)"; [ "$port" = "0" ] && { echo "✋ nenhuma porta livre na faixa $PORT_RANGE_START–$PORT_RANGE_END — aumente DSH_PORT_RANGE_END"; exit 1; }; }
    # por padrão, pule pacotes com conflito interno no core novo (conversation no 0.1.2)
    if [ -z "${DSH_PT_SKIP:-}" ]; then export DSH_PT_SKIP="dsh-client-ui-conversation"; fi
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
    DEP="$(deps_root "$coreRoot")"
    if [ -n "${DSH_PT_SKIP:-}" ]; then
      echo "  ℹ DSH_PT_SKIP ativo — sem apply de patches; só regeneração (pt-ride)."
    elif DSH_CORE_PKGS="$DEP" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --check >/dev/null 2>&1; then
      DSH_CORE_PKGS="$DEP" "$REPO/core-i18n-pt/tools/apply-pt-core.sh" --force >/dev/null 2>&1 && echo "  ✔ patches pt-BR aplicados ($DEP)"
    else
      echo "  ℹ patches antigos não encaixam neste core — usando só regeneração (pt-ride)…"
    fi
    node "$REPO/core-i18n-pt/tools/pt-ride.mjs" --root "$DEP" >/dev/null 2>&1 && echo "  ✔ pt-BR garantido via pt-ride (tabela de traduções)"
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
        full="$(/usr/bin/pm2 logs "dsh-env-$name" --nostream --lines 200 2>/dev/null | grep -oE 'http[^ ]*:'"$port"'[^ ]*' | tail -1)"
        echo "ℹ '$name' pede autenticação — abra com o token: ${full:-http://127.0.0.1:$port}"
        break
      fi
      sleep 2
    done
    [ "$code" = "200" ] || echo "⚠ não respondeu 200 ainda — veja: pm2 logs dsh-env-$name / $envdir"
    echo "Ambiente pronto em $envdir  (atalho: $envdir/start.sh)"
    write_launcher "$name"
    # garante FreeLLMAPI com CORS loopback (qualquer porta do harness)
    if [ -f "$REPO/core-i18n-pt/tools/ensure-freellmapi-loopback.sh" ]; then
      "$REPO/core-i18n-pt/tools/ensure-freellmapi-loopback.sh" >/dev/null 2>&1 && echo "  ✔ FreeLLMAPI: CORS loopback garantido"
    fi
    echo "── teste de sanidade do ambiente ──"
    sanity_test "$name" || true
    ;;
  start|stop|remove)
    name="${2:-}"; m="$BASE/$name/meta.json"
    [ -f "$m" ] || { echo "ambiente '$name' não existe"; exit 1; }
    case "$cmd" in
      start) /usr/bin/pm2 start "dsh-env-$name" >/dev/null 2>&1 && echo "✔ iniciado (URL no meta.json)";;
      stop) /usr/bin/pm2 stop "dsh-env-$name" >/dev/null 2>&1 && echo "✔ parado (ambiente preservado)";;
      remove)
        /usr/bin/pm2 delete "dsh-env-$name" >/dev/null 2>&1 || true
        rm -f "/home/deploy/.local/share/applications/dsh-env-$name.desktop"
        rm -rf "$BASE/$name"
        update-desktop-database /home/deploy/.local/share/applications >/dev/null 2>&1 || true
        echo "✔ ambiente '$name' removido (incluindo atalho do menu)";;
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
  desktop)
    name="${2:-}"
    [ -n "$name" ] || { echo "uso: core-env.sh desktop <nome>"; exit 2; }
    write_launcher "$name"
    ;;
  test)
    name="${2:-}"
    [ -n "$name" ] || { echo "uso: core-env.sh test <nome>"; exit 2; }
    sanity_test "$name"
    ;;
  ports)
    echo "══ Portas dos ambientes DeepSeek Harness ══"
    for m in "$BASE"/*/meta.json; do
      [ -f "$m" ] || continue
      node -e 'const m=require(process.argv[1]);console.log(`  ${m.name.padEnd(18)} porta ${m.port}  ${m.url}`)' "$m"
    done
    [ -z "$(ls -d "$BASE"/*/meta.json 2>/dev/null)" ] && echo "  (nenhum ambiente)"
    echo
    free_ports_help
    nxt="$(alloc_env_port)"
    echo "  próxima porta livre na faixa: ${nxt:-—}"
    ;;
  -h|--help) usage ;;
  *) echo "opção desconhecida: $1"; usage; exit 2 ;;
esac
