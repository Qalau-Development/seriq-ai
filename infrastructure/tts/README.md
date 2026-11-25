# Сервер синтеза речи (предложение, не подключён к деплою)

Озвучивает текст, который сайт показывает на экране: русский — Silero `v5_ru` (голос `xenia`), казахский — ISSAI KazakhTTS (`female1`, Tacotron 2 + Parallel WaveGAN). Числа читаются словами с нужными окончаниями («до ста сорока семи градусов», «жүз қырық жеті градус»). Готовые предложения кэшируются на диске.

Сайт обращается к `GET /tts?lang=ru|kk&text=...`. В разработке `next dev` проксирует `/tts` на `http://127.0.0.1:8100` (переменная `SERIQ_TTS_PROXY`). Если сервера нет, сайт читает текст голосом браузера, как раньше.

## Запуск на своём компьютере

```bash
cd infrastructure/tts
uv venv -p 3.11 .venv && . .venv/bin/activate
uv pip install pip setuptools wheel numpy==1.26.4
uv pip install --no-build-isolation -r requirements.txt
bash fetch_models.sh                                   # около 270 МБ
node --experimental-strip-types dump_texts.mts         # фразы сайта для прогрева
python tts_server.py                                   # http://127.0.0.1:8100
```

Нужны `ffmpeg` и `unzip`. С видеокартой (CUDA) новая фраза готова меньше чем за секунду, на процессоре казахская фраза — 2–8 секунд.

Проверка: `curl -s -G -o test.mp3 localhost:8100/tts -d lang=kk --data-urlencode "text=Жақсы, ұстап тұрыңыз"`.

## Что не решено

- Где запускать на сервере: модели и PyTorch занимают несколько гигабайт, видеокарты на VPS нет. Нужен отдельный сервис в `docker-compose.yml` и маршрут `/tts` в Caddy — решение команды.
- Лицензия Silero `v5_ru`: только некоммерческое использование. KazakhTTS: CC BY 4.0, нужна ссылка на авторов. Подробно — `THIRD_PARTY_NOTICES.md`.
- Казахское произношение проверяет носитель языка.
