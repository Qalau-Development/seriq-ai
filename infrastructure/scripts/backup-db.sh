#!/usr/bin/env bash
# Копия базы аккаунтов (SQLite): sqlite3 .backup, хранится 7 последних копий.
# Запускается вручную или по расписанию на сервере (расписание этим скриптом не создаётся).
# Нужен пакет sqlite3 на сервере и доступ к тому seriq-data (обычно запуск от root).
set -euo pipefail

VOLUME="${SERIQ_VOLUME:-seriq-ai_seriq-data}"
BACKUP_DIR="${SERIQ_BACKUP_DIR:-/opt/seriq-backups}"
KEEP=7

# log — печатает сообщение с меткой
log() { echo "[backup] $*"; }

# find_db — путь к файлу базы: из SERIQ_DB_PATH или из тома Docker
find_db() {
  if [ -n "${SERIQ_DB_PATH:-}" ]; then
    echo "$SERIQ_DB_PATH"
    return
  fi
  local mount
  mount=$(docker volume inspect "$VOLUME" --format '{{ .Mountpoint }}')
  echo "$mount/seriq.db"
}

# prune — оставляет KEEP последних копий
prune() {
  local old
  old=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'seriq-*.db' | sort -r | tail -n +$((KEEP + 1)))
  [ -z "$old" ] || echo "$old" | xargs rm -f --
}

db=$(find_db)
[ -f "$db" ] || { log "нет файла базы: $db"; exit 1; }
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"

dest="$BACKUP_DIR/seriq-$(date -u +%Y%m%d-%H%M%S).db"
sqlite3 "$db" ".backup '$dest'"
chmod 600 "$dest"
result=$(sqlite3 "$dest" "PRAGMA integrity_check")
if [ "$result" != "ok" ]; then
  rm -f -- "$dest"
  log "копия не прошла проверку: $result"
  exit 1
fi
prune
log "готово: $dest, копий: $(find "$BACKUP_DIR" -maxdepth 1 -type f -name 'seriq-*.db' | wc -l | tr -d ' ')"
