#!/usr/bin/env bash
# Локальный бэкенд для разработчиков сайта и приложения: режим mock, временная база SQLite, случайный ключ.
# Запуск из любого места: bash infrastructure/scripts/dev-backend.sh   (порт PORT, по умолчанию 8000; другой python: PYTHON=путь)
# После остановки (Ctrl+C) временная база удаляется, ключ нигде не сохраняется.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PORT="${PORT:-8000}"

# log — печатает сообщение с меткой
log() { echo "[dev-backend] $*"; }

# pick_python — python из .venv репозитория, иначе python3 из PATH
pick_python() {
  if [ -x "$ROOT/.venv/bin/python" ]; then
    echo "$ROOT/.venv/bin/python"
  else
    command -v python3 || true
  fi
}

PY="${PYTHON:-$(pick_python)}"
[ -n "$PY" ] || { log "не найден python3; создайте окружение: uv venv --python 3.12 .venv && uv pip install -r backend/requirements.txt"; exit 1; }
"$PY" -c "import uvicorn, alembic, sqlalchemy, argon2, jwt" 2>/dev/null || {
  log "в окружении нет зависимостей бэкенда; выполните: uv pip install -r backend/requirements.txt (в .venv репозитория)"
  exit 1
}
command -v openssl >/dev/null || { log "нужен openssl для случайного ключа"; exit 1; }

tmp=$(mktemp -d /tmp/seriq-dev.XXXXXX)
trap 'rm -rf "$tmp"' EXIT

export SERIQ_MODE=mock
export SERIQ_DATABASE_URL="sqlite:///$tmp/seriq.db"
SERIQ_AUTH_SECRET=$(openssl rand -base64 48)
export SERIQ_AUTH_SECRET

cd "$ROOT/backend"
"$PY" -m alembic upgrade head

log "бэкенд (mock, временная база $tmp/seriq.db) запускается на порту $PORT"
log "сайт:               SERIQ_API_PROXY=http://localhost:$PORT npm run dev   (в apps/web)"
log "Android-эмулятор:   --dart-define=API_BASE_URL=http://10.0.2.2:$PORT/api/v1"
log "iOS-симулятор:      --dart-define=API_BASE_URL=http://localhost:$PORT/api/v1"
log "проверка:           curl -s localhost:$PORT/api/v1/health   (в ответе должно быть \"database\":\"ok\")"
"$PY" -m uvicorn app.main:app --host 127.0.0.1 --port "$PORT"
