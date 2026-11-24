# №1 — Web (danshikdev)

Ты делаешь сайт SerIQ: главный интерфейс продукта и основное демо на защите. Сайт должен одинаково хорошо работать на компьютере и в браузере телефона.

Плюс из сдаваемого: **видеоинструкция к упражнению** и **сборка презентации**.

Твоя папка: `apps/web/`. Остальное не трогаешь без согласования.

Перед стартом прочитай: [README команды](README.md), [контракт API](../api.md), [архитектуру](../architecture.md).

**Все общие имена** (маршруты страниц, адреса API, переменные окружения, ключи хранения, коды для переводов, порядок сборки) — в [integration.md](integration.md). В коде пиши их ровно так, как там.

---

## Порядок работы

| Когда | Что |
|---|---|
| Сегодня до 18:00 | Проект, главная, инструкция, загрузка видео, экран результата на мок-API |
| Сегодня вечером | Запись с камеры, график угла, занятие и локальная история |
| Ночь | Казахский и русский, адаптивность, снять видеоинструкцию |
| Завтра 9:00–11:00 | Проверка с боевым сервером и настоящей моделью |
| Завтра 11:00–13:30 | Презентация и репетиция |

---

## 1. Создать проект

Из корня репозитория, в ветке `web`:

```bash
git checkout main && git pull
git checkout -b web
cd apps
npx create-next-app@latest web --typescript --tailwind --eslint --app --no-src-dir --import-alias "@/*" --use-npm
cd web
npm install recharts lucide-react
npm run dev        # http://localhost:3000
```

Пакетный менеджер — **npm**, и `package-lock.json` обязательно коммитится: по нему №2 собирает Docker-образ.

### Как сайт попадёт на сервер

- Сайт собирается в Docker-образ из `infrastructure/docker/web.Dockerfile` (его делает №2). Для этого обязательны: `output: "standalone"` в `next.config.ts`, закоммиченный `package-lock.json`, папка `public/`.
- Сайт появится на `https://seriq-ai.qalau.com` **сам**, после того как ты сольёшь первую версию в `main`: деплой включает сервис `web`, когда видит `apps/web/package.json`. Сообщи в чат, когда первая версия в `main`.
- CI на каждый пуш проверяет: есть `package-lock.json`, в `next.config` есть `output: "standalone"`, проходят `npm ci`, `npm run lint`, `npm run build`. Скрипты `lint` и `build` в `package.json` должны быть.
- **Каждое слияние в `main` сразу деплоится.** Если `npm run build` падает, деплой откатывается и сайт остаётся старым. Поэтому перед слиянием всегда `npm run lint` и `npm run build`, а после — проверь вкладку Actions.
- На сервер сам не заходишь: доступ только у Yeskendirr.

Next.js, React, Tailwind CSS, Recharts и Lucide уже записаны в [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md). Добавляешь другой пакет — добавь строку туда в том же PR.

### `next.config.ts`

```ts
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  output: "standalone",
  async rewrites() {
    if (process.env.NODE_ENV !== "development") return [];
    return [
      {
        source: "/api/:path*",
        destination: `${process.env.SERIQ_API_PROXY ?? "http://localhost:8000"}/api/:path*`,
      },
    ];
  },
};

export default nextConfig;
```

Что это даёт:
- `output: "standalone"` нужен для Docker-образа №2.
- В разработке запросы на `/api/...` проксируются на бэкенд, поэтому в коде всегда пишем относительный адрес `/api/v1/...`. На сервере `/api` перехватывает Caddy.
- Чтобы при разработке ходить на боевой мок, а не на локальный бэкенд: `SERIQ_API_PROXY=https://seriq-ai.qalau.com npm run dev`.

---

## 2. Структура

```text
apps/web/
├── app/
│   ├── layout.tsx               # шапка, язык, общая разметка
│   ├── page.tsx                 # главная
│   ├── exercise/page.tsx        # инструкция к E02
│   ├── session/page.tsx         # занятие: запись, загрузка, результат
│   ├── summary/page.tsx         # сводка завершённого занятия
│   └── history/page.tsx         # история занятий
├── components/
│   ├── ui/                      # Button, Card, Badge
│   ├── exercise/                # InstructionVideo, InstructionSteps, FilmingTips
│   ├── video/                   # CameraRecorder, VideoUpload
│   └── analysis/                # VerdictCard, ConfidenceMeter, AngleChart, WarningList, MockBadge
├── lib/
│   ├── api.ts                   # analyze(), разбор ошибок
│   ├── history.ts               # занятия в localStorage
│   └── i18n/                    # ru.ts, kk.ts, useLang()
├── types/
│   └── analysis.ts              # типы контракта API
└── public/media/
    └── instruction-e02.mp4      # видеоинструкция (снимаешь сам)
```

---

## 3. Типы и клиент API

### `types/analysis.ts`

Поля один в один с [api.md](../api.md).

```ts
export type Verdict = "completed" | "check_instructions";
export type CycleLabel = "complete" | "incomplete" | "uncertain";

export interface CycleResult {
  index: number;
  start_s: number;
  end_s: number;
  label: CycleLabel;
  confidence: number;
  verdict: Verdict;
}

export interface AnalysisResult {
  status: "ok";
  analysis_id: string;
  source: "mock" | "model";
  model_version: string;
  exercise: "E02";
  verdict: Verdict;
  summary: { total: number; complete: number; incomplete: number; uncertain: number };
  cycles: CycleResult[];
  angle_series: { fps: number; unit: "deg"; values: (number | null)[] };
  warnings: string[];
  processing_ms: number;
}

export interface ApiError {
  status: "error";
  error: { code: string; message: string };
}
```

### `lib/api.ts`

```ts
import type { AnalysisResult, ApiError } from "@/types/analysis";

// AnalysisError — ошибка анализа с кодом из контракта API
export class AnalysisError extends Error {
  constructor(public code: string, public httpStatus?: number) {
    super(code);
  }
}

// analyzeVideo — отправляет видео на анализ и возвращает результат
export async function analyzeVideo(file: File, mockScenario?: string): Promise<AnalysisResult> {
  const form = new FormData();
  form.append("video", file);
  form.append("exercise", "E02");
  const query = mockScenario ? `?mock_scenario=${mockScenario}` : "";

  let res: Response;
  try {
    res = await fetch(`/api/v1/analysis${query}`, { method: "POST", body: form });
  } catch {
    throw new AnalysisError("network_error");
  }
  const body = (await res.json().catch(() => null)) as AnalysisResult | ApiError | null;
  if (res.ok && body?.status === "ok") return body;
  throw new AnalysisError(body?.status === "error" ? body.error.code : "internal_error", res.status);
}
```

Если хочется показать прогресс загрузки большого файла, используй `XMLHttpRequest` с `upload.onprogress`. Это необязательно.

---

## 4. Камера и загрузка

### Загрузка файла

```tsx
<input type="file" accept="video/mp4,video/quicktime,video/webm" onChange={...} />
```

На телефоне добавь отдельную кнопку с `capture="environment"`: она сразу открывает системную камеру. Это самый надёжный способ записи на мобильных.

### Запись в браузере (`CameraRecorder`)

1. `navigator.mediaDevices.getUserMedia({ video: { facingMode: "environment", width: { ideal: 1280 }, height: { ideal: 720 } }, audio: false })` — 720p достаточно для анализа и сильно уменьшает размер видео.
   Работает только по HTTPS или на `localhost`.
2. Живое превью в `<video autoPlay muted playsInline>`.
3. Обратный отсчёт 3-2-1, потом запись.
4. В `new MediaRecorder(stream, { mimeType, videoBitsPerSecond: 2_500_000 })` ограничь битрейт: 15 секунд — около 5 МБ, загрузка быстрее даже по медленному Wi-Fi.
5. Формат выбирай по поддержке браузера:

```ts
// pickMimeType — выбирает формат записи, который поддерживает браузер
function pickMimeType(): string {
  const types = ["video/mp4", "video/webm;codecs=vp9", "video/webm"];
  return types.find((t) => MediaRecorder.isTypeSupported(t)) ?? "";
}
```

6. Имя файла по формату: `.mp4` для `video/mp4`, иначе `.webm`. Сервер проверяет расширение.
7. Кнопка «Стоп». Автостоп через 30 секунд (цикл упражнения 5–16 с). Если меньше 2 секунд, не отправляй и попроси записать заново.
8. После записи останови все треки камеры (`stream.getTracks().forEach(t => t.stop())`).
9. Если доступ к камере запрещён, покажи понятное сообщение и предложи загрузить файл.

---

## 5. Экраны

Сценарий: **главная → инструкция → занятие (повторения) → сводка**, плюс история.

| Страница | Что на ней |
|---|---|
| `/` | SerIQ, одна фраза о продукте, карточка «Разгибание локтя», кнопки «Начать занятие» и «История», переключатель ҚАЗ / РУС, строка «SerIQ не является медицинским изделием и не ставит диагнозов» |
| `/exercise` | Видеоинструкция, 3–4 шага, советы по съёмке, кнопка «Я готов» |
| `/session` | Список повторений этого занятия; кнопки «Записать с камеры» и «Загрузить видео»; во время анализа — индикатор «Анализируем движение…»; после — результат; кнопки «Ещё повторение» и «Завершить занятие» |
| `/summary` | Всего повторений, выполнено, проверьте инструкцию, не уверены; диаграмма; список попыток |
| `/history` | Прошлые занятия с датой и сводкой; «Удалить историю» |

### Результат анализа

- `verdict === "completed"`: зелёная галочка, «Выполнено».
- `verdict === "check_instructions"`: **нейтральный** значок (не красный крестик), «Проверьте инструкцию» и ссылка на инструкцию.
- Уверенность словами: от 0,8 «высокая», от 0,6 «средняя», ниже «низкая». Процент мелко рядом.
- `source === "mock"`: заметная плашка «Тестовые данные — не результат модели».
- `warnings`: нейтральные подсказки, например `arm_not_visible` → «Убедитесь, что плечо, локоть и кисть видны в кадре».
- **Никаких медицинских советов** («разогните сильнее», «обратитесь к врачу» и подобное).

### График угла (`AngleChart`)

Recharts `LineChart`:
- ось X — секунды: `i / angle_series.fps`;
- ось Y — угол 0–180°, подпись «Угол локтя, °» (180° = рука прямая);
- `null` — разрыв линии (`connectNulls={false}`);
- по возможности подсветить интервал цикла `start_s`–`end_s`.

Это самый наглядный момент для жюри: на графике видно, разогнулась рука до конца или нет.

### Ошибки

Для каждого `code` из [api.md](../api.md#errors), плюс `network_error`, — своя понятная фраза на обоих языках. Пример: `no_pose_detected` → «Рука не видна на видео. Снимите сбоку, чтобы плечо, локоть и кисть были в кадре».

---

## 6. Локальная история (`lib/history.ts`)

- Ключ `localStorage`: `seriq.sessions.v1`.
- Формат — «Local session model» из [architecture.md](../architecture.md). Такой же у Flutter-приложения.
- Функции: `loadSessions()`, `saveSession()`, `startSession()`, `addAttempt()`, `clearHistory()`.
- Сводка считается из `attempts`. На сервер ничего не отправляется.

---

## 7. Языки

- `lib/i18n/ru.ts` и `lib/i18n/kk.ts` с **одинаковыми ключами**, хук `useLang()`, выбор сохраняется в `localStorage` под ключом `seriq.lang` (`ru` или `kk`, по умолчанию `ru`).
- Ключи по шаблону `verdict_<код>`, `label_<код>`, `warning_<код>`, `error_<код>`. Полный список кодов — в [integration.md](integration.md#6-ключи-которые-одинаковы-на-сайте-и-в-приложении), включая клиентские `network_error`, `camera_denied`, `recording_too_short`.
- **Ты ведёшь основной список текстов.** Отдай ключи и переводы №2, чтобы приложение говорило теми же словами.
- Казахский перевод проверьте глазами носителя, не оставляйте машинный перевод без проверки.

---

## 8. Дизайн и доступность

- Белый фон, светло-серые карточки, тёмно-зелёный акцент, тёмный текст. Без лишних градиентов и анимаций.
- Базовый размер текста 18px, кнопки высотой от 56px, контраст не ниже WCAG AA.
- Видимый фокус для клавиатуры, `aria-live="polite"` для статуса анализа.
- Проверить на ширине 375px (телефон), 768px и 1280px.
- Никаких выдуманных медицинских значков и обещаний точности.

---

## 9. Видеоинструкция

Снимаешь сами (клипы из датасета не используем: это записи добровольцев).

Как выглядит упражнение (по видео датасета, по возможности уточните у владельца кейса):
1. Человек сидит за столом, камера сбоку на уровне стола.
2. Локоть стоит на столе, предплечье поднято вертикально, кисть сжата в кулак.
3. Медленно опускает предплечье, разгибая локоть, пока рука не ляжет прямо на стол.

Требования:
- 10–20 секунд, в кадре только рука и стол, без лица.
- Сжать перед добавлением в проект:

```bash
ffmpeg -i raw.mov -vf "scale=-2:720" -c:v libx264 -crf 28 -preset slow -an -movflags +faststart instruction-e02.mp4
```

- Положить в `apps/web/public/media/instruction-e02.mp4`. Для этого пути в `.gitignore` сделано исключение, остальные `.mp4` игнорируются.
- Это же видео Flutter-приложение берёт по адресу `https://seriq-ai.qalau.com/media/instruction-e02.mp4`.

---

## 10. Презентация (до 10 слайдов)

Собираешь ты, содержание по своей части даёт каждый.

| # | Слайд | Кто даёт содержание |
|---|---|---|
| 1 | SerIQ: название, команда, кейс | №1 |
| 2 | Проблема: домашняя реабилитация без специалиста | №1 |
| 3 | Решение и сценарий пользователя | №1 |
| 4 | Архитектура: веб, мобилка, API, AI-ядро, сервер | №2 |
| 5 | Данные: E02, 127 видео, разбиение по добровольцам | №3 |
| 6 | Модель: pose-estimation → угол локтя → признаки → классификатор | №3 |
| 7 | Метрики: balanced accuracy, F1, матрица ошибок, сравнение с базовой моделью | №3 |
| 8 | Демо: скриншоты или живой показ | №1, №2 |
| 9 | Безопасность и этика: видео не храним, нет советов, неуверенность помечаем | все |
| 10 | Ограничения и развитие; использованные Open Source-компоненты и ИИ-инструменты (из [THIRD_PARTY_NOTICES.md](../../THIRD_PARTY_NOTICES.md)) | все |

Защита: 4 минуты рассказ, 2 минуты демо, 2 минуты вопросы. Отрепетировать минимум дважды с секундомером.

---

## 11. Как проверять

1. **Мок-API уже работает на сервере.** Запускай сайт так: `SERIQ_API_PROXY=https://seriq-ai.qalau.com npm run dev` — запросы на `/api/v1/...` пойдут на настоящий мок. Заглушки в коде не нужны. Для тестов разбора ответа без сети — файлы `docs/api-examples/`.
2. Мок-API поддерживает `mock_scenario`: `complete`, `incomplete`, `uncertain`, `no_pose`. Пройди все сценарии и ошибку сети.
3. Перед слиянием в `main`: `npm run lint` и `npm run build` без ошибок.

## Чек-лист «сайт готов»

- [ ] Главная, инструкция, занятие, сводка, история работают
- [ ] Загрузка файла и запись с камеры на компьютере и на телефоне
- [ ] Все исходы и все коды ошибок показываются понятно, на обоих языках
- [ ] Плашка «Тестовые данные» при `source === "mock"`
- [ ] График угла
- [ ] История сохраняется после перезагрузки страницы
- [ ] Видеоинструкция на месте
- [ ] Адаптивность 375 / 768 / 1280
- [ ] `npm run build` проходит, `package-lock.json` закоммичен
