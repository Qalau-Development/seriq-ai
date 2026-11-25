#!/usr/bin/env bash
# Запуск SerIQ одной командой: ставит зависимости, поднимает бэкенд с настоящей моделью и сайт, открывает браузер.
# Запуск из корня репозитория: ./start.sh   (порты: BACKEND_PORT, по умолчанию 8000; WEB_PORT, по умолчанию 3000)
# Остановить: Ctrl+C — бэкенд и сайт выключаются вместе.
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
BACKEND_PORT="${BACKEND_PORT:-8000}"
WEB_PORT="${WEB_PORT:-3000}"
LOGS="$ROOT/.seriq-logs"
HAND_MODEL="$ROOT/data/processed/mp_models/hand_landmarker.task"
HAND_URL="https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"
HAND_SHA="fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1"
PIDS=()

# step — печатает заметный заголовок шага
step() { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
# ok — печатает строку об успехе
ok() { printf '\033[1;32m  ✓ %s\033[0m\n' "$*"; }
# fail — печатает ошибку с подсказкой и выходит
fail() { printf '\033[1;31m  ✗ %s\033[0m\n' "$*" >&2; exit 1; }

# cleanup — останавливает бэкенд и сайт вместе с их дочерними процессами
cleanup() {
  for pid in "${PIDS[@]:-}"; do
    [ -n "$pid" ] || continue
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
  done
  [ ${#PIDS[@]} -gt 0 ] && printf '\nSerIQ остановлен.\n'
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# port_busy — проверяет, занят ли порт на этом компьютере
port_busy() { lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1; }

# wait_url — ждёт, пока адрес ответит, не дольше заданного числа секунд
wait_url() {
  local url=$1 seconds=$2 pid=$3
  for _ in $(seq "$seconds"); do
    curl -fsS "$url" >/dev/null 2>&1 && return 0
    kill -0 "$pid" 2>/dev/null || return 1
    sleep 1
  done
  return 1
}

cd "$ROOT"

step "1/5 Проверяем, что всё нужное установлено"
command -v curl >/dev/null || fail "нет curl"
command -v node >/dev/null || fail "нет Node.js 22: https://nodejs.org (или brew install node@22)"
NODE_MAJOR=$(node -p 'process.versions.node.split(".")[0]')
[ "$NODE_MAJOR" -ge 20 ] || fail "нужен Node.js 22, установлен $(node -v)"
ok "Node.js $(node -v)"
if command -v uv >/dev/null; then
  ok "uv $(uv --version | awk '{print $2}')"
elif command -v python3.12 >/dev/null; then
  ok "Python $(python3.12 -V | awk '{print $2}')"
else
  fail "нужен Python 3.12 (brew install python@3.12) или uv (https://docs.astral.sh/uv/)"
fi
port_busy "$BACKEND_PORT" && fail "порт $BACKEND_PORT занят; запустите так: BACKEND_PORT=8001 ./start.sh"
port_busy "$WEB_PORT" && fail "порт $WEB_PORT занят; запустите так: WEB_PORT=3001 ./start.sh"

step "2/5 Библиотеки бэкенда и модели (первый раз — несколько минут)"
if [ ! -x .venv/bin/python ]; then
  if command -v uv >/dev/null; then uv venv -q --python 3.12 .venv; else python3.12 -m venv .venv; fi
fi
if .venv/bin/python -c "import uvicorn, fastapi, mediapipe, cv2, sklearn, seriq_engine" 2>/dev/null; then
  ok "уже установлены"
else
  if command -v uv >/dev/null; then
    uv pip install -q --python .venv/bin/python -r backend/requirements.txt -e ai-engine
  else
    .venv/bin/python -m pip install -q -r backend/requirements.txt -e ai-engine
  fi
  ok "установлены"
fi
if [ ! -f "$HAND_MODEL" ]; then
  mkdir -p "$(dirname "$HAND_MODEL")"
  curl -fsSL -o "$HAND_MODEL" "$HAND_URL" || fail "не удалось скачать модель MediaPipe; проверьте интернет"
fi
echo "$HAND_SHA  $HAND_MODEL" | shasum -a 256 -c - >/dev/null 2>&1 || { rm -f "$HAND_MODEL"; fail "файл модели MediaPipe повреждён, запустите скрипт ещё раз"; }
ok "модель MediaPipe для кисти на месте"
ok "классификаторы SerIQ: $(ls models/*.joblib | xargs -n1 basename | tr '\n' ' ')"

step "3/5 Пакеты сайта (первый раз — минута-две)"
if [ -d apps/web/node_modules ]; then
  ok "уже установлены"
else
  (cd apps/web && npm ci --no-audit --no-fund --loglevel=error) || fail "npm ci не прошёл"
  ok "установлены"
fi

mkdir -p "$LOGS"

step "4/5 Запускаем бэкенд с моделью (до минуты)"
(
  cd backend
  SERIQ_MODE=model \
  SERIQ_MODEL_PATH="$ROOT/models/e02_classifier.joblib" \
  SERIQ_HAND_MODEL_PATH="$HAND_MODEL" \
  exec ../.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port "$BACKEND_PORT"
) >"$LOGS/backend.log" 2>&1 &
PIDS+=($!)
wait_url "http://127.0.0.1:$BACKEND_PORT/api/v1/health" 120 "${PIDS[0]}" \
  || { tail -n 20 "$LOGS/backend.log" >&2; fail "бэкенд не запустился, журнал: .seriq-logs/backend.log"; }
ok "бэкенд: http://localhost:$BACKEND_PORT/api/docs"

step "5/5 Запускаем сайт"
(
  cd apps/web
  NEXT_TELEMETRY_DISABLED=1 SERIQ_API_PROXY="http://127.0.0.1:$BACKEND_PORT" \
  exec npm run dev -- --port "$WEB_PORT"
) >"$LOGS/web.log" 2>&1 &
PIDS+=($!)
wait_url "http://localhost:$WEB_PORT/" 180 "${PIDS[1]}" \
  || { tail -n 20 "$LOGS/web.log" >&2; fail "сайт не запустился, журнал: .seriq-logs/web.log"; }
HEALTH=$(curl -fsS "http://localhost:$WEB_PORT/api/v1/health" || true)
case "$HEALTH" in
  *'"mode":"model"'*) ok "сайт связан с моделью: $HEALTH" ;;
  *) fail "сайт не видит модель, ответ: $HEALTH" ;;
esac

printf '\n\033[1;32mSerIQ работает:  http://localhost:%s\033[0m\n' "$WEB_PORT"
printf 'Открывайте в Chrome. Остановить: Ctrl+C.  Журналы: .seriq-logs/\n'
if command -v open >/dev/null; then open "http://localhost:$WEB_PORT"; elif command -v xdg-open >/dev/null; then xdg-open "http://localhost:$WEB_PORT" >/dev/null 2>&1 || true; fi

wait
