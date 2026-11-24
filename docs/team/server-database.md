# Включение базы аккаунтов на сервере

Для Yeskendirr. Код аккаунтов и истории уже в `main` и выключен: пока в серверном `.env` нет `SERIQ_DATABASE_URL`, сервер работает как раньше. Здесь шаги, как включить базу, проверить её, настроить копии и откатить. Все шаги выполняются вручную на сервере. Значения секретов в репозиторий, чаты и этот файл не записываются.

Каталог приложения на сервере `/opt/seriq-ai`, проект Docker Compose называется `seriq-ai`, том базы `seriq-ai_seriq-data` (внутри контейнера `/data`), база лежит в нём файлом `seriq.db`. Домен берётся из `SERIQ_DOMAIN` в том же `.env`; ниже он обозначен `<домен>`.

## 0. Перед началом

1. Убедиться, что на сервере задеплоен свежий `main` (в `docker-compose.yml` есть том `seriq-data`, в `infrastructure/caddy/Caddyfile` есть `trusted_proxies`):

```bash
cd /opt/seriq-ai && git log --oneline -1 && grep -n "seriq-data" docker-compose.yml && grep -n trusted_proxies infrastructure/caddy/Caddyfile
```

2. Убедиться, что аккаунты ещё выключены: `curl -s https://<домен>/api/v1/health` должен вернуть `{"status":"ok","mode":"model","version":"0.1.0"}` **без** поля `database`.
3. Сделать копию `.env`, чтобы можно было вернуть: `cp -p .env .env.before-database` (файл с секретами, права `600`, в репозиторий не попадает).

## 1. Переменные в серверном `.env`

В `/opt/seriq-ai/.env` добавить две строки (имена как в `.env.example`):

```text
SERIQ_DATABASE_URL=sqlite:////data/seriq.db
SERIQ_AUTH_SECRET=<случайная строка не короче 32 символов>
```

- Адрес базы показан полностью: четыре слэша после `sqlite:`, путь внутри контейнера.
- Секрет создать на самом сервере и сразу записать в `.env`, не показывая в чате и журналах: `printf 'SERIQ_AUTH_SECRET=%s\n' "$(openssl rand -base64 48)" >> .env`.
- Права: `chmod 600 .env`. Если секрет когда-нибудь утёк, замените значение и перезапустите backend: все выданные access-токены станут недействительными, refresh-токены продолжат работать (они проверяются по базе).
- Сервер **не запустится** с `SERIQ_DATABASE_URL`, если секрет короче 32 символов или пуст. Это защита, не поломка.

## 2. Запуск и миграции

Вариант А (обычный): запустить деплой для текущего `main` (GitHub Actions, «Run workflow» у CI/CD). Скрипт `deploy.sh` сам соберёт образ, выполнит `alembic upgrade head` новым образом и только потом запустит backend. В журнале деплоя должна быть строка `[deploy] миграции базы`.

Вариант Б (вручную, из `/opt/seriq-ai`):

```bash
docker compose build backend
docker compose run --rm --no-deps backend alembic upgrade head
docker compose up -d --wait backend
```

Если миграция упала, `deploy.sh` откатывает код на прошлый коммит, а база остаётся как была (файл создаётся при первой попытке, но пустой).

## 3. Проверка, что всё работает

1. Миграции прошли: текущая версия должна быть последней (`0002`).

```bash
docker compose run --rm --no-deps backend alembic current
```

2. Таблицы созданы (нужен `sqlite3` на сервере, см. шаг 5):

```bash
DB=$(docker volume inspect seriq-ai_seriq-data --format '{{ .Mountpoint }}')/seriq.db
sqlite3 "$DB" ".tables"      # alembic_version attempts login_failures refresh_tokens sessions users
```

3. `/health` показывает базу: `curl -s https://<домен>/api/v1/health` → `{"status":"ok","mode":"model","version":"0.1.0","database":"ok"}`. Значение `unavailable` значит, что база не открывается (смотреть `docker compose logs --tail=50 backend`).
4. Анализ по-прежнему работает: `GET /api/v1/exercises` отвечает, один анализ видео проходит.
5. Регистрация и удаление тестового пользователя (пароль придумайте одноразовый, он в журнал не пишется):

```bash
B=https://<домен>/api/v1
curl -s -X POST $B/auth/register -H 'content-type: application/json' -d '{"login":"check_user","password":"<одноразовый пароль 10+ символов>"}'
# из ответа взять access_token, затем:
curl -s -X DELETE $B/me -H "Authorization: Bearer <access_token>" -H 'content-type: application/json' -d '{"password":"<тот же пароль>"}' -w '%{http_code}\n'   # 204
```

После удаления `sqlite3 "$DB" "select count(*) from users"` должен показать 0 (или число настоящих пользователей).

## 4. Лимит по IP видит реального клиента

Лимиты считаются по адресу клиента из `X-Forwarded-For`. Если цепочка Traefik → Caddy → backend настроена неверно, backend видит один и тот же адрес у всех, и 20 неудачных входов одного человека заблокируют вход всем. Проверить до открытия аккаунтов пользователям:

1. С любого компьютера отправить 21 вход с разными логинами и неверным паролем:

```bash
for i in $(seq 1 21); do curl -s -o /dev/null -w '%{http_code} ' -X POST $B/auth/login -H 'content-type: application/json' -d "{\"login\":\"nobody$i\",\"password\":\"wrong-password-$i\"}"; done; echo
```

Ожидается 20 раз `401` и на 21-й `429`.

2. **Сразу после этого** с другого интернета (телефон на мобильной сети, не Wi-Fi) один вход с неверным паролем: ожидается `401`, а не `429`. Если и там `429`, значит backend видит всех как одного клиента: аккаунты не открывать, проверить заголовки (`trusted_proxies` в Caddyfile, перезапущен ли Caddy: `docker compose up -d --force-recreate caddy`; не приходит ли `X-Forwarded-For` от Traefik).
3. Подделка заголовка не должна обходить лимит: с первого компьютера, пока лимит ещё действует (10 минут), повторить запрос с `-H 'X-Forwarded-For: 1.2.3.4'`: ожидается по-прежнему `429`.
4. Лимит сбрасывается сам через 10 минут; ждать не нужно, если проверка прошла.

## 5. Ночная копия базы

Скрипт `infrastructure/scripts/backup-db.sh` делает копию командой `sqlite3 .backup`, проверяет её целостность и оставляет 7 последних. Сам по расписанию он не запускается.

```bash
apt install sqlite3                                   # один раз
sudo bash /opt/seriq-ai/infrastructure/scripts/backup-db.sh
ls -l /opt/seriq-backups                              # одна копия, права -rw-------
```

Расписание (в `/etc/cron.d/seriq-backup`, время по серверу):

```text
17 3 * * * root /opt/seriq-ai/infrastructure/scripts/backup-db.sh >> /var/log/seriq-backup.log 2>&1
```

Копии лежат на том же сервере: от потери сервера они не защищают. Если нужна защита, периодически забирайте каталог `/opt/seriq-backups` на другой компьютер. Шифрования диска у нас нет.

Проверка восстановления (один раз, на копии, не на рабочей базе):

```bash
sqlite3 /opt/seriq-backups/<файл копии> "PRAGMA integrity_check; select count(*) from users;"
```

Восстановить рабочую базу из копии: остановить backend (`docker compose stop backend`), положить копию на место `seriq.db` в томе (рядом удалить `seriq.db-wal` и `seriq.db-shm`), запустить backend (`docker compose up -d backend`).

## 6. Время входа рядом с анализом

Хэш пароля (argon2id, 64 МиБ) тяжёлый. Пока идёт анализ видео, вход может быть медленнее. Замерить: запустить анализ видео и в это время выполнить вход, записать время (`curl -w '%{time_total}'`) и память (`docker stats --no-stream`). Если вход дольше нескольких секунд или памяти не хватает, поменять параметры в `backend/app/services/passwords.py`; новые параметры применяются к паролям при следующем входе пользователя.

## 7. Как откатить

| Что нужно | Как |
|---|---|
| Выключить аккаунты, данные оставить | В `.env` очистить `SERIQ_DATABASE_URL` (строка `SERIQ_DATABASE_URL=`), `docker compose up -d backend`. Маршруты `/auth`, `/me`, `/sessions`, `/progress` исчезнут, анализ работает как раньше, файл базы остаётся в томе |
| Вернуться к прежнему `.env` | `cp -p .env.before-database .env`, затем `docker compose up -d backend` |
| Откатить код | `deploy.sh` делает это сам, если деплой не прошёл. Миграции только добавляют таблицы, старый код с новой базой работает |
| Откатить миграцию вручную | `docker compose run --rm --no-deps backend alembic downgrade -1`. **Стирает таблицы последней миграции вместе с данными**: сначала сделать копию (шаг 5) |
| Стереть всё без возврата | `docker compose stop backend`, `docker volume rm seriq-ai_seriq-data`. Необратимо; копии в `/opt/seriq-backups` остаются, удалить их отдельно |

## 8. После включения

- Дополнить `docs/privacy-and-security.md` только проверенным: что включено, когда, как проверено (шаги 3 и 4).
- Сказать команде сайта и приложения, что `/health` показывает `database` и клиенты могут показывать вход.
