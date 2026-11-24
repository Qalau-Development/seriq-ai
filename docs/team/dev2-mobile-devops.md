# №2 — Mobile + DevOps (Zenki-Erzat)

Ты отвечаешь за две вещи:

1. **Деплой.** Сервер, HTTPS и CI/CD уже настроены. Твоя задача — добавлять в деплой бэкенд и сайт, когда их код появляется в `main`.
2. **Мобильное приложение на Flutter.** Тот же сценарий, что и на сайте: инструкция, запись повторения, результат, история.

Плюс из сдаваемого: **список ИИ-инструментов** и **инструкция по запуску** в README.

Твои папки и файлы (больше ничего не трогаешь без согласования):

```text
apps/mobile/            ← Flutter-приложение
infrastructure/         ← Dockerfile'ы, Caddy, заглушка, скрипт деплоя
docker-compose.yml      ← какие сервисы запускаются на сервере
.env.example            ← шаблон настроек БЕЗ секретов
.github/workflows/      ← CI/CD
```

Перед стартом прочитай: [README команды](README.md), [контракт API](../api.md), [архитектуру](../architecture.md).

**Все общие имена** (адреса, порты, переменные окружения, ключи хранения, коды для переводов, порядок сборки) — в [integration.md](integration.md). В коде пиши их ровно так, как там.

---

## Порядок работы

| Шаг | Что | Когда | Зависит от |
|---|---|---|---|
| A | Добавить бэкенд в деплой | **как только мок-API от №3 в `main`** | мок-API |
| B | Flutter: проект, экраны, работа с API | сразу, параллельно с A | — (до сервера — на `docs/api-examples/`) |
| A | Добавить сайт в деплой | когда №1 сольёт первую версию | сайт |
| C | Переключить сервер на настоящую модель | завтра утром | №3 скажет «модель готова» |
| D | APK, THIRD_PARTY_NOTICES, README | завтра до 11:00 | — |

Бэкенд в деплое — первым делом: без него ни сайт, ни приложение не проверить на настоящем телефоне.

---

## Часть A. Сервер и деплой

### A0. Что уже сделано

Сервер, HTTPS и CI/CD настроил Yeskendirr. `https://seriq-ai.qalau.com` уже работает и показывает заглушку.

```text
Интернет → Traefik (Dokploy, порты 80/443, HTTPS) → caddy (наш, без портов) ─┬─ /api/* → backend  (добавишь ты)
                                                                              └─ /*     → web      (добавишь ты)
```

**Правила сервера — нарушать нельзя:**

- **Traefik и Dokploy не трогать.** Они общие для всех проектов на сервере.
- **Никаких `ports:`** в `docker-compose.yml`. Наружу смотрит только Traefik.
- **Не включать `ufw`** и не менять сеть сервера: это сломает HTTPS всему серверу.
- **Метки (`labels`) у `caddy` не менять:** по ним Traefik находит наш сайт.
- Доступ к серверу (SSH) — у Yeskendirr. Изменить `.env` на сервере, посмотреть логи контейнера — проси его.
- Пароли, ключи, IP сервера и содержимое `.env` не вставляй в чат с ИИ и не коммить.

### A1. Как работает деплой

Ты **не заходишь на сервер**. Деплой происходит сам:

1. Твои изменения попадают в `main`.
2. GitHub Actions (`.github/workflows/ci-cd.yml`) проверяет `docker-compose.yml`, Caddyfile и `deploy.sh`.
3. Если проверка прошла, Actions по SSH запускает на сервере `infrastructure/scripts/deploy.sh <коммит>`.
4. Скрипт переключает код на этот коммит и выполняет `docker compose up -d --build`.
5. Ждёт, пока сайт ответит. **Если не ответил — откатывает на предыдущий коммит** и помечает запуск красным.

Где смотреть: GitHub → вкладка **Actions** → последний запуск. Зелёный — задеплоено. Красный — открой упавший шаг и читай лог.

Проверь у себя **до** слияния, чтобы не уронить деплой:

```bash
SERIQ_DOMAIN=example.com docker compose config -q
docker run --rm -v "$PWD/infrastructure/caddy/Caddyfile:/etc/caddy/Caddyfile:ro" caddy:2 caddy validate --config /etc/caddy/Caddyfile
```

Обе команды должны завершиться без ошибок.

### A2. Добавить бэкенд (как только мок-API №3 в `main`)

Четыре изменения, лучше отдельными коммитами.

#### 1. `infrastructure/docker/backend.Dockerfile` (новый файл)

```dockerfile
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# системные библиотеки для OpenCV и MediaPipe
RUN apt-get update \
 && apt-get install -y --no-install-recommends libgl1 libglib2.0-0 \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /srv
COPY backend/requirements.txt backend/requirements.txt
RUN pip install --no-cache-dir -r backend/requirements.txt

# ФАЗА 2: раскомментировать, когда №3 скажет, что ai-engine и модель готовы
# COPY ai-engine ai-engine
# RUN pip install --no-cache-dir ./ai-engine
# COPY models models

COPY backend backend
WORKDIR /srv/backend
EXPOSE 8000
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
```

`--workers 1` специально: анализ видео тяжёлый, на 4 ГБ памяти одновременно идёт только один.

#### 2. `docker-compose.yml`: добавить `backend` и внутреннюю сеть

Блок `labels` у `caddy` оставь **ровно как есть**. Меняется только то, что отмечено комментариями:

```yaml
name: seriq-ai

services:
  caddy:
    image: caddy:2
    restart: unless-stopped
    volumes:
      - ./infrastructure/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./infrastructure/placeholder:/srv/placeholder:ro
    networks: [default, dokploy-network]   # добавлена default
    depends_on: [backend]                  # новое
    labels:
      # без изменений, как в текущем файле

  backend:                                 # новый сервис
    build:
      context: .
      dockerfile: infrastructure/docker/backend.Dockerfile
    env_file:
      - path: .env
        required: false
    restart: unless-stopped
    mem_limit: 2g
    networks: [default]
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

networks:
  default: {}                              # новое: внутренняя сеть проекта
  dokploy-network:
    external: true
```

- `backend` подключён **только** к внутренней сети: снаружи и из других проектов его не видно.
- `required: false` нужен для проверки в GitHub Actions, где `.env` нет. На сервере `.env` есть.
- `mem_limit` и ротация логов берегут память и диск сервера.

#### 3. `infrastructure/caddy/Caddyfile`: маршрут `/api/*`

```caddyfile
{
	auto_https off
	admin off
}

:80 {
	encode zstd gzip

	request_body {
		max_size 110MB
	}

	handle /api/* {
		reverse_proxy backend:8000
	}

	handle {
		root * /srv/placeholder
		file_server
	}
}
```

HTTPS здесь выключен специально: его делает Traefik. Лимит 110 МБ чуть больше, чем 100 МБ в API: так бэкенд сам вернёт понятную ошибку `file_too_large`.

#### 4. `.env.example`: переменные бэкенда

```dotenv
SERIQ_DOMAIN=seriq-ai.qalau.com
# mock — тестовые ответы, model — настоящая модель
SERIQ_MODE=mock
# Максимальный размер видео, МБ
SERIQ_MAX_UPLOAD_MB=100
# Путь к файлу модели внутри контейнера
SERIQ_MODEL_PATH=/srv/models/e02_classifier.joblib
```

**Попроси Yeskendirr добавить эти же строки в `.env` на сервере** до слияния.

#### Проверка после слияния

Дождись зелёного запуска в Actions, потом:

```bash
curl -s https://seriq-ai.qalau.com/api/v1/health
# ожидаем: {"status":"ok","mode":"mock",...}

curl -s -X POST -F "video=@test.mp4" "https://seriq-ai.qalau.com/api/v1/analysis?mock_scenario=uncertain"
# ожидаем JSON с "source":"mock" и "label":"uncertain"
```

Для проверки подойдёт любое своё короткое `.mp4` на 2–60 секунд, видео из датасета не нужно. Документация API в браузере: `https://seriq-ai.qalau.com/api/docs`.

**Как только health отвечает — напиши в чат команды.**

### A3. Добавить сайт (когда №1 сольёт первую версию)

Работает, только когда №1 включит `output: "standalone"` в `apps/web/next.config.ts` и закоммитит `package-lock.json`.

#### 1. `infrastructure/docker/web.Dockerfile` (новый файл)

```dockerfile
FROM node:22-alpine AS deps
WORKDIR /app
COPY apps/web/package.json apps/web/package-lock.json ./
RUN npm ci

FROM node:22-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY apps/web ./
RUN npm run build

FROM node:22-alpine
WORKDIR /app
ENV NODE_ENV=production PORT=3000 HOSTNAME=0.0.0.0
COPY --from=build /app/.next/standalone ./
COPY --from=build /app/.next/static ./.next/static
COPY --from=build /app/public ./public
EXPOSE 3000
CMD ["node", "server.js"]
```

#### 2. `docker-compose.yml`: сервис `web`

```yaml
  web:
    build:
      context: .
      dockerfile: infrastructure/docker/web.Dockerfile
    restart: unless-stopped
    mem_limit: 512m
    networks: [default]
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"
```

И у `caddy`: `depends_on: [backend, web]`.

#### 3. Caddyfile: последний `handle` вместо заглушки

```caddyfile
	handle {
		reverse_proxy web:3000
	}
```

После слияния `https://seriq-ai.qalau.com` открывает сайт.

### A4. Переключение на настоящую модель (завтра утром)

Когда №3 скажет «ai-engine и модель в main»:

1. В `backend.Dockerfile` раскомментируй три строки блока «ФАЗА 2», слей в `main`.
2. Попроси Yeskendirr поставить `SERIQ_MODE=model` в `.env` на сервере.
3. После деплоя: `curl -s https://seriq-ai.qalau.com/api/v1/health` → `"mode":"model"`.
4. Загрузи тестовое видео: в ответе `"source":"model"`.
5. Запиши время анализа (поле `processing_ms`) и передай Yeskendirr: он снимет `docker stats` на сервере для отчёта.

### A5. Нагрузка на сервер

Сейчас `deploy.sh` собирает образы **прямо на сервере**. Для Caddy это мелочь. Но сборка сайта Next.js и установка MediaPipe на 4 ГБ памяти — тяжёлые и медленные. Если сборка `web` или `backend` на сервере падает с `Killed` или идёт слишком долго, следующий шаг — **собирать образы в GitHub Actions и публиковать в GitHub Container Registry**, а на сервере делать только `docker compose pull`. Это изменение `ci-cd.yml` и `deploy.sh`, делать вместе с Yeskendirr.

### A6. Если что-то не работает

| Симптом | Где смотреть | Частая причина |
|---|---|---|
| Красный шаг «Проверка docker-compose.yml» | лог шага в Actions | Ошибка в YAML: отступы, лишний символ |
| Красный шаг «Проверка Caddyfile» | лог шага в Actions | Ошибка синтаксиса Caddyfile |
| Красный «Деплой на сервер», в логе «откат» | лог шага в Actions | Сервис упал при старте или сайт не ответил. Сайт вернулся на прошлую версию. Попроси Yeskendirr: `docker compose logs backend` |
| 502 на `/api/...` | — | `backend` не запустился: ошибка в коде или requirements |
| Сборка падает с `Killed` | лог деплоя | Не хватило памяти при сборке, см. A5 |
| 413 при загрузке | — | Видео больше 100 МБ |
| Изменения не появились | вкладка Actions | Изменения не слиты в `main`, или деплой ещё идёт |

## Часть B. Flutter-приложение

### B0. Что поставить на компьютер

- Flutter SDK: https://docs.flutter.dev/get-started/install
- Android Studio (нужен Android SDK) и телефон на Android с включённой отладкой по USB, или эмулятор.
- Для iPhone нужны Mac с Xcode и Apple ID. Если Mac нет, делаем только Android, этого достаточно для демо.

Проверка:

```bash
flutter doctor
```

Всё, что нужно для Android, должно быть с галочкой.

### B1. Создать проект

Из корня репозитория, в ветке `mobile`:

```bash
git checkout main && git pull
git checkout -b mobile
cd apps
flutter create --org kz.qalau --project-name seriq_mobile mobile
cd mobile
flutter run          # должно запуститься демо-приложение со счётчиком
```

### B2. Пакеты

```bash
flutter pub add http image_picker shared_preferences fl_chart video_player uuid intl
```

| Пакет | Зачем |
|---|---|
| `http` | отправить видео на сервер |
| `image_picker` | снять видео системной камерой или выбрать из галереи (проще, чем свой экран камеры) |
| `shared_preferences` | хранить историю занятий на телефоне |
| `fl_chart` | график угла локтя |
| `video_player` | показать видеоинструкцию |
| `uuid` | ID для локальных занятий |
| `intl` | формат дат |

Все эти пакеты уже записаны в [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md). Добавляешь другой пакет — добавь и строку туда.

### B3. Структура папок

```text
apps/mobile/lib/
├── main.dart                       # запуск приложения
├── app.dart                        # тема (цвета, шрифты), маршруты
├── core/
│   ├── config.dart                 # адрес API, адрес видеоинструкции
│   └── strings.dart                # все тексты на казахском и русском
├── models/
│   ├── analysis_result.dart        # ответ API: AnalysisResult, CycleResult, AngleSeries
│   └── session.dart                # локальное занятие и попытки
├── services/
│   ├── api_client.dart             # POST /analysis, разбор ошибок
│   └── history_storage.dart        # сохранить и прочитать занятия
├── features/
│   ├── home/home_screen.dart
│   ├── exercise/exercise_screen.dart
│   ├── session/session_screen.dart
│   ├── result/result_screen.dart
│   ├── summary/summary_screen.dart
│   └── history/history_screen.dart
└── widgets/
    ├── big_button.dart             # крупная кнопка
    ├── verdict_card.dart           # «Выполнено» или «Проверьте инструкцию»
    └── angle_chart.dart            # график угла
```

### B4. Ключевой код

Ниже готовые основы. Комментарии: одна короткая строка над функцией или классом, на русском.

#### `core/config.dart`

```dart
// AppConfig — адреса сервера, задаются при сборке
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://seriq-ai.qalau.com/api/v1',
  );
  static const instructionVideoUrl = String.fromEnvironment(
    'INSTRUCTION_VIDEO_URL',
    defaultValue: 'https://seriq-ai.qalau.com/media/instruction-e02.mp4',
  );
}
```

Запуск с нужным адресом:

```bash
flutter run --dart-define=API_BASE_URL=https://seriq-ai.qalau.com/api/v1
```

#### `models/analysis_result.dart`

Поля один в один с [api.md](../api.md).

```dart
// CycleResult — результат одного цикла упражнения
class CycleResult {
  final int index;
  final double startS;
  final double endS;
  final String label;
  final double confidence;
  final String verdict;

  CycleResult.fromJson(Map<String, dynamic> j)
      : index = j['index'] as int,
        startS = (j['start_s'] as num).toDouble(),
        endS = (j['end_s'] as num).toDouble(),
        label = j['label'] as String,
        confidence = (j['confidence'] as num).toDouble(),
        verdict = j['verdict'] as String;
}

// AngleSeries — угол локтя по времени для графика
class AngleSeries {
  final double fps;
  final List<double?> values;

  AngleSeries.fromJson(Map<String, dynamic> j)
      : fps = (j['fps'] as num).toDouble(),
        values = (j['values'] as List)
            .map((v) => v == null ? null : (v as num).toDouble())
            .toList();
}

// AnalysisResult — полный ответ POST /analysis
class AnalysisResult {
  final String analysisId;
  final String source;
  final String verdict;
  final List<CycleResult> cycles;
  final AngleSeries angleSeries;
  final List<String> warnings;

  AnalysisResult.fromJson(Map<String, dynamic> j)
      : analysisId = j['analysis_id'] as String,
        source = j['source'] as String,
        verdict = j['verdict'] as String,
        cycles = (j['cycles'] as List)
            .map((c) => CycleResult.fromJson(c as Map<String, dynamic>))
            .toList(),
        angleSeries = AngleSeries.fromJson(j['angle_series'] as Map<String, dynamic>),
        warnings = List<String>.from(j['warnings'] as List);

  bool get isMock => source == 'mock';
}
```

#### `services/api_client.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config.dart';
import '../models/analysis_result.dart';

// ApiException — ошибка API с кодом из контракта
class ApiException implements Exception {
  final String code;
  final int? httpStatus;
  ApiException(this.code, [this.httpStatus]);
}

// ApiClient — отправляет видео на анализ
class ApiClient {
  final String baseUrl;
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  // analyze — загружает видео и возвращает результат анализа
  Future<AnalysisResult> analyze(String filePath, {String? mockScenario}) async {
    final uri = Uri.parse('$baseUrl/analysis').replace(
      queryParameters: mockScenario == null ? null : {'mock_scenario': mockScenario},
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['exercise'] = 'E02'
      ..files.add(await http.MultipartFile.fromPath('video', filePath));

    try {
      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final response = await http.Response.fromStream(streamed);
      final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (response.statusCode == 200 && body['status'] == 'ok') {
        return AnalysisResult.fromJson(body);
      }
      final code = (body['error'] as Map<String, dynamic>?)?['code'] as String?;
      throw ApiException(code ?? 'internal_error', response.statusCode);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('network_error');
    }
  }
}
```

#### `models/session.dart` и `services/history_storage.dart`

Формат хранения такой же, как на сайте: см. «Local session model» в [architecture.md](../architecture.md). Ключ в `shared_preferences`: `seriq.sessions.v1`, значение — JSON-строка со списком занятий.

Что нужно реализовать:
- `Session { id, exercise, startedAt, attempts }`
- `Attempt { analysisId, at, verdict, label, confidence, source }`
- `HistoryStorage.loadSessions()`, `saveSession(session)`, `clearAll()`
- у `Session` — геттеры `total`, `completeCount`, `incompleteCount`, `uncertainCount`

#### `core/strings.dart`

Простой словарь без сложной локализации. Язык выбирается на главном экране и сохраняется в `shared_preferences` под ключом `seriq.lang` (`ru` или `kk`, по умолчанию `ru`). Названия ключей текстов — по шаблону из [integration.md](integration.md#6-ключи-которые-одинаковы-на-сайте-и-в-приложении).

```dart
// Strings — тексты интерфейса на казахском и русском
class Strings {
  static const _ru = {
    'verdict_completed': 'Выполнено',
    'verdict_check_instructions': 'Проверьте инструкцию',
    'start_session': 'Начать занятие',
    'record_attempt': 'Записать повторение',
    'pick_video': 'Выбрать видео',
    'analyzing': 'Анализируем движение…',
    'mock_badge': 'Тестовые данные, не результат модели',
    'error_no_pose_detected': 'Рука не видна на видео. Снимите сбоку, чтобы плечо, локоть и кисть были в кадре.',
    'error_network_error': 'Нет связи с сервером. Проверьте интернет и попробуйте снова.',
    // остальные ключи — по списку ниже
  };
  static const _kk = {
    'verdict_completed': 'Орындалды',
    'verdict_check_instructions': 'Нұсқаулықты тексеріңіз',
    // казахские тексты согласовать с №1, у вас должны быть одинаковые
  };

  // of — возвращает текст по ключу для выбранного языка
  static String of(String lang, String key) =>
      (lang == 'kk' ? _kk : _ru)[key] ?? _ru[key] ?? key;
}
```

**Тексты для казахского и русского берите общие с №1**, чтобы сайт и приложение говорили одинаково. Сообщение на каждый код ошибки из [api.md](../api.md#errors) обязательно.

### B5. Экраны

Цвета: белый фон, светло-серые карточки, тёмно-зелёный акцент, тёмный текст. Кнопки крупные (высота от 56), текст от 18. Пользователь может быть пожилым.

| Экран | Что на нём |
|---|---|
| **Главный** | Название SerIQ, карточка «Разгибание локтя», кнопки «Начать занятие» и «История», переключатель ҚАЗ / РУС, строка мелким шрифтом: «SerIQ не является медицинским изделием» |
| **Инструкция** | Видеоинструкция (`video_player` по `AppConfig.instructionVideoUrl`), 3–4 шага текстом, советы по съёмке, кнопка «Я готов» |
| **Занятие** | Список уже сделанных повторений, кнопки «Записать повторение» (камера) и «Выбрать видео» (галерея), кнопка «Завершить занятие» |
| **Анализ** | Индикатор загрузки и «Анализируем движение…». Время анализа на сервере пока не измерено; клиент ждёт до 3 минут, потом показывает `network_error` |
| **Результат** | Большая карточка вердикта, уверенность, график угла, предупреждения, кнопки «Ещё повторение» и «Посмотреть инструкцию». Если `isMock`, показать плашку «Тестовые данные» |
| **Сводка** | После «Завершить»: всего повторений, выполнено, проверьте инструкцию, не уверены; простая диаграмма; список попыток |
| **История** | Прошлые занятия с датой и сводкой; кнопка «Удалить историю» |

Запись повторения:

```dart
final video = await ImagePicker().pickVideo(
  source: ImageSource.camera,            // ImageSource.gallery для выбора файла
  maxDuration: const Duration(seconds: 60),
);
if (video != null) {
  final result = await ApiClient().analyze(video.path);
}
```

Правила для экрана результата:

- `verdict == "completed"`: зелёная галочка и «Выполнено».
- `verdict == "check_instructions"`: **нейтральный** значок (не красный крестик) и «Проверьте инструкцию».
- Уверенность словами: от 0,8 «высокая», от 0,6 «средняя», ниже «низкая». Число в процентах — мелко рядом.
- График: ось X — секунды (`индекс / fps`), ось Y — угол 0–180°. `null` — разрыв линии.
- Никаких советов вроде «разогните сильнее». Только «Проверьте инструкцию» и подсказки по съёмке.

Советы по съёмке для экрана инструкции:
- Поставьте телефон боком к себе, на уровне стола.
- В кадре должны быть плечо, локоть и кисть.
- Хорошее освещение, однотонный фон.
- Одно повторение — одна запись.

### B6. Разрешения

**Android**, файл `android/app/src/main/AndroidManifest.xml`, внутри `<manifest>` до `<application>`:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

Без этой строки **релизный APK не сможет ходить в интернет**, хотя в режиме отладки всё будет работать.

**iOS**, файл `ios/Runner/Info.plist`, внутри `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>Камера нужна, чтобы записать упражнение.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Запись видео с камеры требует доступа к микрофону.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Доступ к галерее нужен, чтобы выбрать видео упражнения.</string>
```

### B7. Проверка и сборка

Разбор ответа сначала проверь на файлах из `docs/api-examples/` (их кладёт №3): если `AnalysisResult.fromJson` читает их без ошибок, он прочитает и ответ сервера.

Как проверить работу на моке, не снимая упражнение:

```dart
ApiClient().analyze(path, mockScenario: 'uncertain');   // также complete, incomplete, no_pose
```

Пройди все четыре сценария и ошибку сети (выключи интернет).

Сборка APK для сдачи:

```bash
cd apps/mobile
flutter analyze                 # без ошибок
flutter build apk --release --dart-define=API_BASE_URL=https://seriq-ai.qalau.com/api/v1
# файл: build/app/outputs/flutter-apk/app-release.apk
```

APK в git **не коммитим**. Его прикладываем к сдаче отдельно.

### B8. Чек-лист «приложение готово»

- [ ] Открывается, язык переключается, выбор сохраняется
- [ ] Видеоинструкция проигрывается
- [ ] Запись с камеры и выбор из галереи отправляются на сервер
- [ ] Все исходы показываются правильно: completed, check_instructions, uncertain, ошибки
- [ ] Плашка «Тестовые данные», когда `source == "mock"`
- [ ] График угла рисуется
- [ ] Сводка занятия и история сохраняются после перезапуска
- [ ] Релизный APK работает на реальном телефоне с настоящим сервером

---

## Часть C. Что ты собираешь для сдачи

### Список ИИ-инструментов, Open Source и данных

Всё это в одном файле — [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md) в корне репозитория. Там уже есть таблицы для датасета, модели позы, библиотек, инфраструктуры и ИИ-ассистентов; лицензии проверены по официальным реестрам.

Твоя задача:
- когда добавляешь пакет во Flutter (`flutter pub add …`) или что-то в инфраструктуру, которого нет в таблице, добавь строку в том же PR: название, ссылка, лицензия (смотри на pub.dev или GitHub), для чего;
- перед сдачей пройди по файлу: всё, что реально используется, отмечено, а то, от чего отказались, удалено;
- спроси у каждого, какими ИИ-ассистентами пользовался, и допиши в раздел «AI assistants used in development»;
- строки с пометкой `To verify` к сдаче должны быть проверены.

### Инструкция по запуску

Раздел в `README.md`: как запустить локально (бэкенд, сайт, приложение) и как задеплоить на сервер. Части про бэкенд и сайт попроси у №3 и №1, свою напиши сам.

---

## Как работать с ИИ-помощником

1. **Давай контекст.** В начале разговора вставь этот файл и [api.md](../api.md). Скажи: «Я №2, делаю Flutter-приложение и сервер. Работаю только в apps/mobile и infrastructure».
2. **Маленькие шаги.** Один экран или один файл за раз. После каждого шага запускай: `flutter analyze`, `flutter run`, на сервере — `docker compose ps` и `curl`.
3. **Не давай менять контракт.** Если ИИ предлагает переименовать поля API или поменять формат — нет. Поля только из api.md. Вопрос по API — к №3.
4. **Не давай трогать чужие папки:** `apps/web`, `backend`, `ai-engine`.
5. **Секреты.** Пароль от сервера, SSH-ключи и `.env` в чат не вставляй.
6. **Застрял больше чем на 30 минут** — пиши в чат команды. Не сиди молча.

Примеры запросов:

> Вот контракт API (вставка api.md) и структура проекта (вставка B3). Напиши `lib/features/result/result_screen.dart`: экран результата по разделу B5. Используй AnalysisResult из models/analysis_result.dart. Тексты бери через Strings.of(lang, key).

> `docker compose logs caddy` выдаёт вот это (вставка логов без секретов). Домен seriq-ai.qalau.com, DNS указывает на сервер. Почему нет сертификата?
