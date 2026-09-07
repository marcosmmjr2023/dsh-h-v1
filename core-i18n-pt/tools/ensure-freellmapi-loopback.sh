#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# ensure-freellmapi-loopback.sh — deixa o servidor FreeLLMAPI
# (~/projects/freellmapi) aceitar o dashboard/harness de QUALQUER porta
# loopback (3080/3081/3110/3111/…), reconstrói e o mantém sob o pm2
# (nome: freellmapi). Idempotente. Rode como deploy.
# ═══════════════════════════════════════════════════════════════
set -euo pipefail

SRV=/home/deploy/projects/freellmapi/server
[ -f "$SRV/src/app.ts" ] || { echo "✋ FreeLLMAPI não encontrado em $SRV — pule (sem servidor local)."; exit 0; }

# 1) libera loopback em qualquer porta no callback de CORS (idempotente)
if grep -q 'isLoopbackOrigin\|LOOPBACK_CORS_RE\|/^https?:\\/\\/(localhost|127' "$SRV/src/app.ts"; then
  echo "ℹ CORS loopback já liberado (src/app.ts)."
else
  python3 - "$SRV/src/app.ts" <<'PYEOF'
import sys
p=sys.argv[1]; s=open(p).read()
old="      callback(null, !origin || allowedCorsOrigins.has(origin));"
new=("      const LOOPBACK_CORS_RE = /^https?:\\/\\/(?:localhost|127\\.0\\.0\\.1|\\[::1\\])(?::\\d+)?$/;\n"
     "      callback(null, !origin || allowedCorsOrigins.has(origin) || LOOPBACK_CORS_RE.test(origin));")
assert old in s, "callback nao encontrado"
s=s.replace(old,new,1)
open(p,'w').write(s)
print("✔ CORS loopback adicionado em src/app.ts")
PYEOF
fi

# 2) reconstrói
echo "▶ build (tsc)…"
(cd "$SRV" && npm run build >/dev/null 2>&1) || { echo "✋ build falhou — use npm run build em $SRV"; exit 1; }

# 3) garante sob o pm2 (com as mesmas origens de sempre + loopback)
ORIGINS="http://localhost:5173,http://127.0.0.1:5173,http://[::1]:5173,http://127.0.0.1:3080,http://127.0.0.1:3081"
if ! /usr/bin/pm2 describe freellmapi >/dev/null 2>&1; then
  pkill -f 'projects/freellmapi/server/dist/index.js' 2>/dev/null || true
  sleep 1
  (cd "$SRV" && PORT=3002 HOST=127.0.0.1 DASHBOARD_ORIGINS="$ORIGINS" \
    /usr/bin/pm2 start dist/index.js --name freellmapi >/dev/null 2>&1)
  echo "▶ freellmapi iniciado sob pm2"
else
  /usr/bin/pm2 restart freellmapi >/dev/null 2>&1 && echo "ℹ freellmapi reiniciado (pm2)"
fi

sleep 2
echo "=== teste CORS ==="
for port in 3081 3110 3111; do
  h=$(curl -s -i -H "Origin: http://127.0.0.1:$port" http://127.0.0.1:3002/api/ping | grep -i '^access-control-allow-origin' | tr -d '\r')
  echo "origem :$port → ${h:-SEM CORS}"
done
curl -fsS --max-time 3 http://127.0.0.1:3002/api/ping -o /dev/null && echo "✔ ping 3002 OK"
