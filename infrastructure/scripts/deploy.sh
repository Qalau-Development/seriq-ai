#!/usr/bin/env bash
# Запускается на сервере из GitHub Actions: bash -s -- <sha> < deploy.sh
set -euo pipefail

REPO_URL="https://github.com/Qalau-Development/seriq-ai.git"
APP_DIR="/opt/seriq-ai"
SHA="${1:?usage: deploy.sh <git-sha>}"

# log — печатает сообщение с меткой
log() { echo "[deploy] $*"; }

# update_code — приводит каталог к нужному коммиту
update_code() {
  [ -d .git ] || { git init -q; git remote add origin "$REPO_URL"; }
  git fetch -q --depth=1 origin "$1"
  git reset -q --hard FETCH_HEAD
}

# start_stack — пересобирает и поднимает контейнеры
start_stack() {
  docker compose up -d --build --remove-orphans
}

# wait_healthy — ждёт ответ сайта через Traefik, не завися от DNS
wait_healthy() {
  local domain
  domain=$(grep -E '^SERIQ_DOMAIN=' .env | cut -d= -f2-)
  for _ in $(seq 1 30); do
    if curl -fsS -o /dev/null -k --resolve "${domain}:443:127.0.0.1" "https://${domain}/"; then
      return 0
    fi
    sleep 2
  done
  return 1
}

cd "$APP_DIR"
[ -f .env ] || { log "нет $APP_DIR/.env"; exit 1; }

previous=$(git rev-parse -q --verify HEAD 2>/dev/null || true)
log "обновление до $SHA (было: ${previous:-ничего})"
update_code "$SHA"
start_stack

if wait_healthy; then
  log "сайт отвечает"
  docker image prune -f >/dev/null
  exit 0
fi

log "сайт не отвечает"
docker compose ps || true
if [ -n "$previous" ]; then
  log "откат на $previous"
  update_code "$previous"
  start_stack
fi
exit 1
