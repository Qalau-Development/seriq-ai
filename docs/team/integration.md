# Единые имена и сборка в одно целое

Это **единственный источник** всех общих имён проекта. Если имя есть здесь, в коде пишем ровно так. Если нужно новое общее имя или изменение, сначала добавляем сюда, и все трое соглашаются.

Формат ответа API подробно описан в [../api.md](../api.md). Здесь — сводка всего, что связывает части между собой.

## 1. Адреса

### API (бэкенд, №3)

| Метод | Путь | Кто вызывает |
|---|---|---|
| GET | `/api/v1/health` | №2 (проверка сервера), веб и мобилка (по желанию) |
| POST | `/api/v1/analysis` | веб, мобилка |
| GET | `/api/v1/exercises` | веб, мобилка — каталог упражнений, см. [api.md](../api.md#several-exercises) |
| GET | `/api/docs` | люди: интерактивная документация |
| GET | `/api/openapi.json` | схема API |

Параметр только для мок-режима: `?mock_scenario=complete|incomplete|uncertain|no_pose`.

### Статические файлы (сайт, №1)

| Путь | Файл в репозитории | Кто использует |
|---|---|---|
| `/media/instruction-e02.mp4` | `apps/web/public/media/instruction-e02.mp4` | веб, мобилка |

### Страницы и экраны

Одинаковые названия маршрутов на сайте и в приложении.

| Маршрут | Веб (`apps/web/app/…`) | Flutter (`apps/mobile/lib/features/…`) | Что это |
|---|---|---|---|
| `/` | `page.tsx` | `home/home_screen.dart` | Главная |
| `/exercise` | `exercise/page.tsx` | `exercise/exercise_screen.dart` | Инструкция к E02 |
| `/session` | `session/page.tsx` | `session/session_screen.dart` | Занятие: запись, загрузка, результат |
| `/summary` | `summary/page.tsx` | `summary/summary_screen.dart` | Сводка занятия |
| `/history` | `history/page.tsx` | `history/history_screen.dart` | История |

Во Flutter экран результата открывается из `/session` как отдельный экран `result/result_screen.dart`; на сайте результат показывается внутри `/session`.

## 2. Адреса в разных окружениях

| Окружение | Сайт | API |
|---|---|---|
| Сервер | `https://seriq-ai.qalau.com` | `https://seriq-ai.qalau.com/api/v1` |
| Локально | `http://localhost:3000` | `http://localhost:8000/api/v1` |

- **Веб** всегда обращается к относительному `/api/v1/...`. Локально Next.js проксирует его на `http://localhost:8000` (или на адрес из `SERIQ_API_PROXY`), на сервере `/api` перехватывает Caddy.
- **Flutter** использует полный адрес из `API_BASE_URL`. Для работы с телефона нужен сервер с доменом: `localhost` на телефоне — это сам телефон.

## 3. Сервисы, порты, файлы на сервере

Снаружи сервер обслуживает **Traefik** из Dokploy: он держит порты 80 и 443 и выдаёт HTTPS-сертификаты. Traefik общий для всех проектов на сервере, **его не трогаем**. У проекта SerIQ публичных портов нет вообще.

| Сервис в `docker-compose.yml` | Порт | Сети | Собирается из | Статус |
|---|---|---|---|---|
| `caddy` | 80 (только внутри) | `dokploy-network` + внутренняя сеть проекта | образ `caddy:2` + `infrastructure/caddy/Caddyfile` | **работает**, отдаёт заглушку |
| `backend` | 8000 (только внутри) | внутренняя сеть проекта | `infrastructure/docker/backend.Dockerfile` | включается сам, когда есть `backend/requirements.txt` |
| `web` | 3000 (только внутри) | внутренняя сеть проекта | `infrastructure/docker/web.Dockerfile` | включается сам, когда есть `apps/web/package.json` |

Маршрутизация: Traefik → `caddy:80` по Docker-меткам в `docker-compose.yml`. Caddy: `/api/*` → `backend:8000`, всё остальное → `web:3000`. Пока их нет, Caddy отдаёт страницу из `infrastructure/placeholder/`.

Каталог проекта на сервере: `/opt/seriq-ai`. Настройки: `/opt/seriq-ai/.env`, только на сервере.

**Проверки** запускаются на каждый пуш в любую ветку: конфигурация, тесты бэкенда и движка, линтер и сборка сайта, `flutter analyze`, связка всех сервисов. **Деплой** — только из `main`, после зелёных проверок: по SSH `infrastructure/scripts/deploy.sh <коммит>` → сборка нужных сервисов → healthcheck'и → проверка главной и `/api/v1/health` → при сбое откат на предыдущий коммит. Значит, **сломанный `main` = сломанный сайт на время отката**: перед слиянием проверяй свою часть.

| Что | Путь в репозитории | Путь в контейнере `backend` |
|---|---|---|
| Код бэкенда | `backend/` | `/srv/backend` |
| AI-ядро | `ai-engine/` (пакет `seriq_engine`) | ставится через `pip install ./ai-engine` |
| Модель | `models/e02_classifier.joblib` | `/srv/models/e02_classifier.joblib` |
| Веса MediaPipe Hand Landmarker | не в репозитории: скачиваются при сборке образа (URL версии 1, проверка sha256) | `/srv/models/hand_landmarker.task` |
| Точка входа | `backend/app/main.py`, объект `app` | `uvicorn app.main:app` |

## 4. Переменные окружения

| Переменная | Где | Значение по умолчанию | Смысл |
|---|---|---|---|
| `SERIQ_DOMAIN` | `.env` на сервере, метки Traefik в `docker-compose.yml` | `seriq-ai.qalau.com` | Домен |
| `SERIQ_MODE` | `.env`, бэкенд | `mock` | `mock` или `model`. Добавляется в `.env.example` вместе с `backend` |
| `SERIQ_MAX_UPLOAD_MB` | `.env`, бэкенд | `100` | Лимит размера видео |
| `SERIQ_MODEL_PATH` | `.env`, бэкенд | `/srv/models/e02_classifier.joblib` | Путь к модели |
| `SERIQ_HAND_MODEL_PATH` | образ бэкенда (`ENV` в `backend.Dockerfile`); локально — для обучения | `/srv/models/hand_landmarker.task` | Путь к весам MediaPipe Hand Landmarker |
| `SERIQ_API_PROXY` | веб, только при разработке | `http://localhost:8000` | Куда проксировать `/api` |
| `API_BASE_URL` | Flutter, `--dart-define` | `https://seriq-ai.qalau.com/api/v1` | Адрес API |
| `INSTRUCTION_VIDEO_URL` | Flutter, `--dart-define` | `https://seriq-ai.qalau.com/media/instruction-e02.mp4` | Видеоинструкция |

## 5. Связь бэкенда и AI-ядра (№3)

```python
from seriq_engine.pipeline import analyze_video

result = analyze_video(path)   # path: временный файл видео
```

`analyze_video` возвращает словарь с полями `verdict`, `summary`, `cycles`, `angle_series`, `warnings`, `model_version` и необязательным `pose` — ровно в формате [api.md](../api.md). Бэкенд добавляет `status`, `analysis_id`, `source`, `exercise`, `processing_ms`. Если руки нет на видео, `analyze_video` выбрасывает ошибку, и бэкенд превращает её в `422 no_pose_detected`.

Мок-режим возвращает ответ **той же формы**, поэтому переход с мока на модель для клиентов незаметен: меняется только `"source": "mock"` на `"source": "model"`.

## 6. Ключи, которые одинаковы на сайте и в приложении

| Что | Значение |
|---|---|
| Ключ хранения занятий | `seriq.sessions.v1` (веб: `localStorage`, Flutter: `shared_preferences`) |
| Ключ языка | `seriq.lang`, значения `ru` или `kk`, по умолчанию `ru` |
| Формат занятия | «Local session model» в [../architecture.md](../architecture.md#local-session-model) |
| Уверенность словами | от 0,8 — высокая, от 0,6 — средняя, ниже — низкая |

### Коды, для которых нужен текст на обоих языках

Вердикты: `completed`, `check_instructions`.

Метки: `complete`, `incomplete`, `uncertain`.

Предупреждения: `arm_not_visible`.

Ошибки API: `missing_video`, `empty_file`, `unsupported_exercise`, `file_too_large`, `unsupported_format`, `video_unreadable`, `video_too_short`, `video_too_long`, `no_pose_detected`, `busy`, `internal_error`.

Ошибки клиента: `network_error`, `camera_denied`, `recording_too_short`.

Ключи переводов называются по шаблону `verdict_<код>`, `label_<код>`, `warning_<код>`, `error_<код>`. Например: `verdict_completed`, `error_no_pose_detected`. Основной список текстов ведёт №1 в `apps/web/lib/i18n/`, №2 берёт тексты оттуда.

## 7. Примеры ответов для проверки без сервера

В `docs/api-examples/` лежат настоящие ответы мок-API (тест бэкенда проверяет, что они совпадают с ответами мока):

| Файл | Сценарий |
|---|---|
| `analysis-complete.json` | `mock_scenario=complete` |
| `analysis-incomplete.json` | `mock_scenario=incomplete` |
| `analysis-uncertain.json` | `mock_scenario=uncertain` |
| `error-no-pose.json` | `mock_scenario=no_pose` |

Веб и Flutter проверяют на них разбор ответа. Если разбор работает на этих файлах, он заработает и с сервером.

## 8. Ветки

| Ветка | Кто | Что в неё попадает |
|---|---|---|
| `ai` | №3 | `backend/`, `ai-engine/`, `ml-training/`, `models/`, `docs/api-examples/` |
| `web` | №1 | `apps/web/` |
| `mobile` | №2 | `apps/mobile/` |
| `infra` | №2 | `infrastructure/`, `docker-compose.yml`, `.env.example` |

Каждый меняет только свои папки, поэтому слияния в `main` проходят без конфликтов.

## 9. Порядок сборки

| Шаг | Кто | Что сливается в `main` | Проверка |
|---|---|---|---|
| 0 | Yeskendirr | Сервер, Traefik, HTTPS, CI/CD, заглушка — **готово** | `https://seriq-ai.qalau.com` открывает заглушку |
| 1 | №3 | мок-API в `backend/` + `docs/api-examples/` — **готово** | `curl https://seriq-ai.qalau.com/api/v1/health` → `"mode":"mock"` |
| 2 | — (автоматически) | бэкенд задеплоен — **готово** | анализ на моке отвечает по HTTPS |
| 3 | №1 | первая версия `apps/web`; деплоится сама | сайт открывается по домену, анализ на моке работает |
| 4 | №2 | Flutter на `API_BASE_URL` домена | приложение получает ответ мока с сервера |
| 5 | №3 | `ai-engine/`, модель, режим `model` в бэкенде | локально: настоящее видео → `"source":"model"` |
| 6 | №3 | `SERIQ_MODE=model` в `.env` на сервере (`ai-engine` и модель попадают в образ сами) | `"mode":"model"` |
| 7 | все | — | Сквозная проверка ниже |

Деплой после каждого шага происходит сам, после слияния в `main`. Результат — во вкладке **Actions** на GitHub.

## 10. Как модель отвечает на живых записях (знать всем)

Модель `e02-logreg2-1`, признаки и пороги **заморожены**: их не меняем без №3, а №3 — без нового теста на людях, которых не было в обучении. Подробности и все числа — в [model-evaluation.md](../model-evaluation.md#end-to-end-checks). Проверено на 7 записях команды с iPhone (24.11), 6 из 6 с известным ожиданием совпали:

| Что сделал человек | Что вернёт API | Что видит пользователь |
|---|---|---|
| Опустил руку до стола и остановил запись | `complete`, уверенность 0,87–0,97 | «Выполнено» |
| То же другой рукой, с другой стороны кадра | `complete` | «Выполнено» |
| Опустил наполовину и поднял обратно | `incomplete`, ~0,90 | «Проверьте инструкцию» |
| Опустил до стола и **поднял обратно** | `uncertain`, ~0,6 | «Проверьте инструкцию» — модель обучена на «опустить и остановить» |
| Опустил наполовину и **задержал** | чаще всего `uncertain` | «Проверьте инструкцию»; при разгибании ~63°+ от старта может быть `complete` |
| Рука частично вне кадра | `uncertain` + `warnings: ["arm_not_visible"]` | «Проверьте инструкцию» и подсказка показать руку целиком |
| Руки нет в кадре | `422 no_pose_detected` | ошибка «рука не найдена» |

Что из этого следует для сайта и приложения:

- **`uncertain` — нормальный ответ, а не сбой.** Его стоит показывать спокойно, с подсказкой о съёмке, и без слова «ошибка».
- **Инструкция должна просить «опустить руку до стола и остановить запись».** Возврат руки вверх даёт `uncertain`.
- **Показывайте измеренный угол** (максимум `angle_series`): при остановке на полпути человек увидит «до 137°», а не «полностью».
- **Время:** анализ 6–10 с для 4K с iPhone (`processing_ms`) плюс загрузка 12–24 МБ; на медленном канале это 30–60 с. Нужен индикатор ожидания, и запрос нельзя обрывать раньше чем через ~2 минуты.
- **`pose`** (необязательное поле) даёт точки кисти и локоть для линии на видео; `null` = кисть в этом кадре не найдена, ничего не дорисовывать.

## 11. Сквозная проверка

- [ ] `https://seriq-ai.qalau.com` открывается, сертификат действителен
- [ ] `GET /api/v1/health` → `"mode":"model"`
- [ ] Сайт на компьютере: загрузка видео → результат с `source: model`, график, сводка
- [ ] Сайт на телефоне: запись с камеры → результат
- [ ] Приложение: запись с камеры и выбор из галереи → результат
- [ ] История сохраняется на сайте и в приложении
- [ ] Видеоинструкция проигрывается на сайте и в приложении
- [ ] Ошибки: файл не того формата, видео без руки, нет интернета — понятные сообщения
- [ ] Оба языка
- [ ] Запасное демо на ноутбуке: локальный бэкенд + сайт работают без интернета

## 12. Четыре упражнения

E02 не меняется. Подробно — в [api.md](../api.md#several-exercises). В бэкенде сделано: каталог `GET /api/v1/exercises`, поле `measure`, мок для всех четырёх упражнений, адаптер к движку с фолбэком на прежний `pipeline` для E02. На сервере `ready=true` только у упражнений с загруженной моделью (сейчас E02).

| Что | Значение |
|---|---|
| Упражнения | `E01` подъём предмета, `E02` разгибание локтя, `E03` подъём запястья, `E04` раскрытие кисти |
| Новое поле ответа `measure` | `name`: `elbow_angle` / `wrist_lift` / `hand_openness` / `lift_height`; `unit`: `deg` / `percent` / `hand_lengths`; `value`; `series` |
| `angle_series` | остаётся, только для E02 (старые клиенты) |
| `pose` | у E01, E03, E04 без `elbow`, только точки кисти |
| Новый маршрут | `GET /api/v1/exercises` → `[{id, measure:{name, unit}, ready}]`; `ready=false` → «скоро» |
| Мок | отдаёт ответы для всех четырёх упражнений (сделано) |
| Стык бэкенда и движка | `seriq_engine.exercises.catalog()` и `seriq_engine.exercises.analyze_video(path, exercise)`; неготовое упражнение → `UnsupportedExercise` (`api_code = "unsupported_exercise"`) |
