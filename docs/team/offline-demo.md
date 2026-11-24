# Запасное демо на ноутбуке без интернета

На случай, если на защите нет интернета или сервер недоступен: бэкенд с настоящей моделью и сайт запускаются на ноутбуке. Модель, веса MediaPipe и сайт работают локально, во время работы в интернет ничего не загружают.

Проверено 24.11 на MacBook: все страницы сайта открываются, анализ через сайт отвечает с `"source":"model"`. **С выключенным Wi-Fi не проверялось** — сделайте это один раз до защиты (шаг 4).

## 1. Подготовка — один раз, с интернетом

Из корня репозитория, Python 3.12, Node 22:

```bash
uv venv --python 3.12 .venv && source .venv/bin/activate
uv pip install -r backend/requirements.txt -e ai-engine
mkdir -p data/processed/mp_models
curl -L -o data/processed/mp_models/hand_landmarker.task \
  https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task
echo "fbc2a30080c3c557093b5ddfc334698132eb341044ccee322ccf8bcf3607cde1  data/processed/mp_models/hand_landmarker.task" | shasum -a 256 -c -
(cd apps/web && npm ci)
```

Модель `models/e02_classifier.joblib` уже лежит в репозитории. Датасет для демо не нужен.

## 2. Запуск — два терминала

Терминал 1, бэкенд с моделью:

```bash
cd backend
SERIQ_MODE=model \
SERIQ_MODEL_PATH=$PWD/../models/e02_classifier.joblib \
SERIQ_HAND_MODEL_PATH=$PWD/../data/processed/mp_models/hand_landmarker.task \
../.venv/bin/uvicorn app.main:app --port 8000
```

Терминал 2, сайт:

```bash
cd apps/web
NEXT_TELEMETRY_DISABLED=1 npm run dev
```

Сайт: http://localhost:3000. Именно `npm run dev`, а не `npm start`: проксирование `/api` на бэкенд включено только в режиме разработки. Камера в браузере на `localhost` работает без HTTPS.

## 3. Проверка

```bash
curl -s localhost:3000/api/v1/health    # {"status":"ok","mode":"model","version":"0.1.0"}
```

Перед показом откройте все страницы один раз: в режиме разработки первая загрузка страницы компилируется несколько секунд.

## 4. До защиты: проверить без интернета

Выключите Wi-Fi, запустите шаги 2–3, запишите одно повторение с веб-камеры через сайт и загрузите одно видео с телефона.

## Ограничение: файлы больше 10 МБ

Прокси `next dev` пропускает только первые 10 МБ запроса: видео больше 10 МБ (например, 4K с iPhone) через локальный сайт падает с ошибкой 500. На сервере этого нет — там `/api` обрабатывает Caddy.

Исправление в `apps/web/next.config.ts` (зона №1), проверено локально: файл 58 МБ проходит.

```ts
experimental: { proxyClientMaxBodySize: "100mb" },
```

Пока исправления нет: показывайте запись с веб-камеры (она маленькая) или снимайте на телефон в 1080p.

## Остановить

`Ctrl+C` в обоих терминалах.
