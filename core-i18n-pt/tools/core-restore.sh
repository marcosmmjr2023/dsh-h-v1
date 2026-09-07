#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# core-restore.sh — restaura uma cópia de segurança criada por
# core-backup.sh (histórico de sessões, config, credenciais locais).
# Uso:
#   core-restore.sh list
#   core-restore.sh <nome-do-backup>      (ex.: core-20260907-041500)
#   core-restore.sh latest
# Rode como root ou deploy. NÃO mexe no núcleo npm (isso é do rollback de
# versão); restaura apenas os dados do usuário (~/.dsh*).
# ═══════════════════════════════════════════════════════════════
set -uo pipefail

BASE="${DSH_BACKUP_ROOT:-/home/deploy/.dsh-core-backups}"
DEPLOY=deploy

cmd="${1:-list}"
case "$cmd" in
  list)
    ls -1dt "$BASE"/core-* 2>/dev/null | sed 's#.*/##' || echo "nenhum backup em $BASE"
    exit 0
    ;;
esac

sel="$cmd"
[ "$sel" = "latest" ] && sel="$(ls -1dt "$BASE"/core-* 2>/dev/null | head -1 | sed 's#.*/##')"
SRC="$BASE/$sel"
[ -d "$SRC" ] || { echo "✋ backup '$sel' não encontrado (core-restore.sh list)"; exit 1; }
echo "▶ restaurando de $SRC"

restore_home() { # home destino  backup
  local home="$1" b="$2" name
  name="$(basename "$home")"
  [ -d "$b/$name" ] || return 0
  for sub in sessions storages; do
    if [ -d "$b/$name/$sub" ]; then
      mkdir -p "$home"
      # cópia sem apagar o que já existe (mescla; nunca destrói)
      cp -a "$b/$name/$sub/." "$home/$sub/" 2>/dev/null && echo "  ✔ $name/$sub mesclado"
    fi
  done
  if [ -d "$b/$name/config" ]; then
    for f in "$b/$name/config"/*; do
      [ -f "$f" ] || continue
      base="$(basename "$f")"
      cp -a "$f" "$home/$base" 2>/dev/null && echo "  ✔ $name/$base"
    done
  fi
}

restore_home /home/deploy/.dsh "$SRC"
restore_home /home/deploy/.dsh-v2 "$SRC"

if [ "$(id -u)" -eq 0 ]; then
  chown -R "$DEPLOY":"$DEPLOY" /home/deploy/.dsh /home/deploy/.dsh-v2 2>/dev/null || true
fi
echo "✔ restauração concluída de $SRC."
echo "  Reinicie a GUI (pm2 restart dsh-web-v2) e verifique o histórico de sessões."
