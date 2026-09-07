#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# core-backup.sh — COPIA DE SEGURANÇA antes de mexer no CORE.
# Preserva tudo que importa ao usuário e à recuperação:
#   • histórico de SESSÕES (v1 ~/.dsh e v2 ~/.dsh-v2) — nunca se perde;
#   • config: settings.yaml, .credentials.yaml (700), .dsh-version.json,
#     cordis.patch.yml, plugins .js do home, storages/leves;
#   • manifesto do core (versões instaladas, marcador pt, data).
# Local: ~/.dsh-core-backups/<core-<ts>>/   (últimas 5 mantidas; nunca sync)
#
# Uso: core-backup.sh [--label <nome>] [--root <dir-base>]
# Pode rodar como deploy ou root (se root, devolve a posse ao deploy).
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

HOME_DEPLOY="/home/deploy"
BASE="${DSH_BACKUP_ROOT:-$HOME_DEPLOY/.dsh-core-backups}"
LABEL="core"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --label) LABEL="${2:-core}"; shift 2 ;;
    --root) BASE="${2:-}"; shift 2 ;;
    *) echo "opção desconhecida: $1"; exit 2 ;;
  esac
done

TS="$(date +%Y%m%d-%H%M%S)"
DEST="$BASE/$LABEL-$TS"
HOMES=(/home/deploy/.dsh /home/deploy/.dsh-v2)

mkdir -p "$DEST"
echo "▶ backup do core pré-operação → $DEST"

# 1) histórico de sessões + storages leves de cada home
for h in "${HOMES[@]}"; do
  [ -d "$h" ] || continue
  name="$(basename "$h")"
  mkdir -p "$DEST/$name"
  for sub in sessions storages; do
    [ -d "$h/$sub" ] && cp -a "$h/$sub" "$DEST/$name/" && echo "  ✔ $name/$sub"
  done
done

# 2) config e componentes do usuário (sem node_modules, sem logs)
for h in "${HOMES[@]}"; do
  [ -d "$h" ] || continue
  name="$(basename "$h")"
  mkdir -p "$DEST/$name/config"
  for f in settings.yaml .credentials.yaml .dsh-version.json cordis.patch.yml \
           .anonymous-user-id manifest.json; do
    [ -f "$h/$f" ] && cp -a "$h/$f" "$DEST/$name/config/" && echo "  ✔ $name/config/$f"
  done
  # plugins .js na raiz do home (camada custom)
  find "$h" -maxdepth 1 -name '*.js' -type f -exec cp -a {} "$DEST/$name/config/" \; 2>/dev/null
  # storages raiz leves (json)
  for f in "$h"/storages/*.json; do [ -f "$f" ] && cp -a "$f" "$DEST/$name/config/" 2>/dev/null; done
done

# 3) manifesto do core (versões + marcador pt)
{
  echo "data=$(date -Is)"
  for p in /opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh /usr/lib/node_modules/@deepseek-ai/dsh; do
    [ -f "$p/package.json" ] && echo "core $p → $(node -e 'console.log(require(process.argv[1]+"/package.json").version)' "$p" 2>/dev/null)"
  done
  for m in /opt/dsh-tui/node/lib/node_modules/@deepseek-ai/dsh/node_modules/.dsh-core-pt-applied \
           /usr/lib/node_modules/@deepseek-ai/dsh/node_modules/.dsh-core-pt-applied; do
    [ -f "$m" ] && { echo "marcador-pt $m →"; cat "$m"; }
  done
  echo "historico core:"; [ -f /home/deploy/.dsh-v2/.dsh-core-history.json ] && cat /home/deploy/.dsh-v2/.dsh-core-history.json
} > "$DEST/manifest.txt"
echo "✔ manifesto em $DEST/manifest.txt"

# permissões: nunca ficar root se criado por root
chmod -R u+rwX,go= "$DEST" 2>/dev/null || true
chmod 700 "$DEST" 2>/dev/null || true
if [ "$(id -u)" -eq 0 ]; then chown -R deploy:deploy "$DEST" 2>/dev/null || true; fi

# mantém as 5 mais recentes
ls -d "$BASE"/core-* 2>/dev/null | sort -r | tail -n +6 | while read -r old; do
  rm -rf "$old"; echo "  (removido backup antigo: $old)"
done

echo "✔ backup concluído: $DEST"
