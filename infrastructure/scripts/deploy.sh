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

# pick_services — выбирает сервисы, код которых уже есть в репозитории
pick_services() {
  local list="caddy"
  [ -f backend/requirements.txt ] && list="$list backend"
  [ -f apps/web/package.json ] && list="$list web"
  echo "$list"
}

# db_enabled — в .env задан SERIQ_DATABASE_URL (аккаунты включены)
db_enabled() {
  local url
  url=$(grep -E '^SERIQ_DATABASE_URL=' .env | cut -d= -f2- | tr -d "\"' " || true)
  [ -n "$url" ]
}

# migrate_db — применяет миграции Alembic новым образом backend, только если база включена
migrate_db() {
  db_enabled || return 0
  [ -f backend/alembic.ini ] || return 0
  log "миграции базы"
  docker compose run --rm --no-deps backend alembic upgrade head
}

# start_stack — собирает образы по одному, при аргументе migrate применяет миграции и поднимает сервисы до готовности
start_stack() {
  local services
  services=$(pick_services)
  log "сервисы: $services"
  mkdir -p ai-engine models
  for s in $services; do
    [ "$s" = caddy ] || docker compose build "$s" || return 1
  done
  if [ "${1:-}" = migrate ]; then
    migrate_db || return 1
  fi
  # shellcheck disable=SC2086
  docker compose up -d --wait --wait-timeout 180 --remove-orphans $services || return 1
}

# caddy_changed — Caddyfile отличается между прошлым и новым коммитом; без прошлого коммита или при ошибке git считаем, что менялся
caddy_changed() {
  [ -n "${1:-}" ] || return 0
  if git diff --quiet "$1" HEAD -- infrastructure/caddy/Caddyfile 2>/dev/null; then
    return 1
  fi
  return 0
}

# recreate_caddy — пересоздаёт caddy и ждёт healthy: при admin off Caddy сам Caddyfile не перечитывает
recreate_caddy() {
  log "Caddyfile изменился, пересоздаю caddy"
  docker compose up -d --force-recreate --wait --wait-timeout 60 --no-deps caddy
}

# check_site — проверяет ответ сайта и API через Traefik, не завися от DNS
check_site() {
  local domain
  domain=$(grep -E '^SERIQ_DOMAIN=' .env | cut -d= -f2-)
  local paths="/"
  [ -f backend/requirements.txt ] && paths="$paths /api/v1/health"
  for p in $paths; do
    curl -fsS -o /dev/null -k --retry 10 --retry-delay 2 --retry-all-errors \
      --resolve "${domain}:443:127.0.0.1" "https://${domain}${p}" || return 1
  done
}

cd "$APP_DIR"
[ -f .env ] || { log "нет $APP_DIR/.env"; exit 1; }

previous=$(git rev-parse -q --verify HEAD 2>/dev/null || true)
log "обновление до $SHA (было: ${previous:-ничего})"
update_code "$SHA"

caddy_new=no
if caddy_changed "$previous"; then
  caddy_new=yes
fi

if start_stack migrate && { [ "$caddy_new" = no ] || recreate_caddy; } && check_site; then
  log "сервисы готовы, сайт отвечает"
  docker image prune -f --filter label=project=seriq-ai >/dev/null
  exit 0
fi

log "деплой не удался"
docker compose ps || true
docker compose logs --tail=40 || true
if [ -n "$previous" ]; then
  log "откат на $previous"
  update_code "$previous"
  start_stack || true
  if [ "$caddy_new" = yes ]; then
    recreate_caddy || true
  fi
fi
exit 1
