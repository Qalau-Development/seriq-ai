import logging
import threading
import time
from datetime import timedelta

import jwt
import pytest
from alembic.autogenerate import compare_metadata
from alembic.migration import MigrationContext
from argon2 import PasswordHasher
from fastapi.testclient import TestClient
from sqlalchemy import func, select
from starlette.requests import Request

from app.db.base import Base, utc_now
from app.db.engine import make_engine, make_session_factory
from app.db.models import LoginFailure, RefreshToken, User
from app.main import create_app
from app.services import accounts, passwords, ratelimit
from tests.conftest import SECRET

PASSWORD = "correct horse battery"
WEB = {"X-SerIQ-Client": "web"}


# make_client — клиент с базой; peer задаёт адрес, с которого «пришёл» запрос
def make_client(peer=None):
    kwargs = {"client": (peer, 5000)} if peer else {}
    return TestClient(create_app(), raise_server_exceptions=False, **kwargs)


# client — клиент в режиме mock с включённой базой
@pytest.fixture
def client(accounts_env):
    return make_client()


# db — сессия к той же базе для проверки содержимого таблиц
@pytest.fixture
def db(accounts_env):
    engine = make_engine(accounts_env)
    with make_session_factory(engine)() as session:
        yield session
    engine.dispose()


# register — регистрирует пользователя и возвращает ответ
def register(client, login="anna_k", password=PASSWORD, headers=None):
    return client.post("/api/v1/auth/register", json={"login": login, "password": password}, headers=headers)


# login — входит и возвращает ответ
def login(client, login="anna_k", password=PASSWORD, headers=None):
    return client.post("/api/v1/auth/login", json={"login": login, "password": password}, headers=headers)


# bearer — заголовок Authorization из ответа входа
def bearer(response):
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


# travel — сдвигает время сервера вперёд на seconds секунд
def travel(monkeypatch, seconds):
    monkeypatch.setattr(accounts, "utc_now", lambda: utc_now() + timedelta(seconds=seconds))


# assert_error — проверяет единый формат ошибки
def assert_error(response, status, code):
    assert response.status_code == status, response.text
    body = response.json()
    assert body["status"] == "error" and body["error"]["code"] == code and body["error"]["message"]


# test_register — регистрация даёт 201, пользователя и пару токенов; в базе хэш пароля и хэш refresh
def test_register(client, db):
    response = register(client)
    assert response.status_code == 201
    body = response.json()
    assert set(body) == {"user", "access_token", "refresh_token", "expires_in"}
    assert set(body["user"]) == {"id", "login", "created_at"} and body["user"]["login"] == "anna_k"
    assert body["user"]["created_at"].endswith("Z") and body["expires_in"] == 900
    user = db.scalar(select(User))
    assert user.password_hash.startswith("$argon2id$") and PASSWORD not in user.password_hash
    token = db.scalar(select(RefreshToken))
    assert token.token_hash != body["refresh_token"] and len(token.token_hash) == 64


# test_login_ok — вход по паролю, логин без учёта регистра
def test_login_ok(client):
    register(client)
    for name in ("anna_k", "ANNA_K"):
        response = login(client, name)
        assert response.status_code == 200 and response.json()["user"]["login"] == "anna_k"


# test_same_answer_for_unknown_login_and_wrong_password — ответ на неверный логин и неверный пароль один и тот же
def test_same_answer_for_unknown_login_and_wrong_password(client):
    register(client)
    wrong_password = login(client, "anna_k", "wrong password 123")
    unknown_login = login(client, "nobody", "wrong password 123")
    assert_error(wrong_password, 401, "invalid_credentials")
    assert wrong_password.status_code == unknown_login.status_code
    assert wrong_password.json() == unknown_login.json()


# test_unknown_login_still_hashes — для несуществующего логина всё равно считается хэш пароля (одинаковое время ответа)
def test_unknown_login_still_hashes(client, monkeypatch):
    calls = []
    original = passwords.verify_password

    # counting — запоминает хэш, с которым сверяют пароль
    def counting(stored, password):
        calls.append(stored)
        return original(stored, password)

    monkeypatch.setattr(passwords, "verify_password", counting)
    login(client, "nobody", "whatever password")
    assert len(calls) == 1 and calls[0].startswith("$argon2id$")


# test_login_taken — занятый логин даёт 409, регистр не важен
def test_login_taken(client):
    register(client)
    assert_error(register(client, "ANNA_K"), 409, "login_taken")


# test_weak_password — правила пароля: 10–128 символов и без логина внутри
@pytest.mark.parametrize("password", ["short123", "a" * 9, "a" * 129, "my-ANNA_K-secret", "anna_k"])
def test_weak_password(client, password):
    assert_error(register(client, "anna_k", password), 400, "weak_password")


# test_password_length_edges — ровно 10 и ровно 128 символов допустимы, пробелы и юникод тоже
@pytest.mark.parametrize("password", ["a" * 10, "b" * 128, "пароль со спичками", "x y z w v u"])
def test_password_length_edges(client, password):
    assert register(client, "user_" + str(abs(hash(password)) % 1000), password).status_code == 201


# test_invalid_login_format — логин: 3–32 символа ASCII из букв, цифр и . _ -
@pytest.mark.parametrize("name", ["ab", "a" * 33, "anna k", "anna@mail.kz", "аня_к", "annа_k", "a/b/c", ""])
def test_invalid_login_format(client, name):
    assert_error(register(client, name), 400, "invalid_request")


# test_bad_body — неполное тело даёт invalid_request, а не missing_video, и пароль в ответ не попадает
def test_bad_body(client):
    response = client.post("/api/v1/auth/register", json={"password": "SECRET-PASSWORD-VALUE"})
    assert_error(response, 400, "invalid_request")
    assert "SECRET-PASSWORD-VALUE" not in response.text
    assert_error(client.post("/api/v1/auth/login", content=b"not json", headers={"content-type": "application/json"}), 400, "invalid_request")


# test_me — GET /me по access-токену
def test_me(client):
    response = register(client)
    me = client.get("/api/v1/me", headers=bearer(response))
    assert me.status_code == 200 and me.json() == response.json()["user"]


# test_me_bad_tokens — нет токена, мусор, чужая подпись, нет пользователя: invalid_token; истёкший: token_expired
def test_me_bad_tokens(client):
    user_id = register(client).json()["user"]["id"]
    now = int(time.time())
    assert_error(client.get("/api/v1/me"), 401, "invalid_token")
    assert_error(client.get("/api/v1/me", headers={"Authorization": "Bearer garbage"}), 401, "invalid_token")
    assert_error(client.get("/api/v1/me", headers={"Authorization": "Basic abc"}), 401, "invalid_token")
    foreign = jwt.encode({"sub": user_id, "iat": now, "exp": now + 900}, "another-secret-another-secret-123456", algorithm="HS256")
    assert_error(client.get("/api/v1/me", headers={"Authorization": f"Bearer {foreign}"}), 401, "invalid_token")
    ghost = jwt.encode({"sub": "no-such-user", "iat": now, "exp": now + 900}, SECRET, algorithm="HS256")
    assert_error(client.get("/api/v1/me", headers={"Authorization": f"Bearer {ghost}"}), 401, "invalid_token")
    no_exp = jwt.encode({"sub": user_id, "iat": now}, SECRET, algorithm="HS256")
    assert_error(client.get("/api/v1/me", headers={"Authorization": f"Bearer {no_exp}"}), 401, "invalid_token")
    expired = jwt.encode({"sub": user_id, "iat": now - 1000, "exp": now - 100}, SECRET, algorithm="HS256")
    assert_error(client.get("/api/v1/me", headers={"Authorization": f"Bearer {expired}"}), 401, "token_expired")


# test_access_token_lifetime — access-токен живёт 15 минут
def test_access_token_lifetime(client):
    token = register(client).json()["access_token"]
    claims = jwt.decode(token, SECRET, algorithms=["HS256"])
    assert claims["exp"] - claims["iat"] == 900


# test_refresh_rotation — refresh меняет пару, старый токен перестаёт работать
def test_refresh_rotation(client, monkeypatch):
    first = register(client).json()
    second = client.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]})
    assert second.status_code == 200
    assert set(second.json()) == {"access_token", "refresh_token", "expires_in"}
    assert second.json()["refresh_token"] != first["refresh_token"]
    assert client.get("/api/v1/me", headers=bearer(second)).status_code == 200


# test_refresh_reuse_is_theft — повтор использованного токена после 10 секунд отзывает всю цепочку
def test_refresh_reuse_is_theft(client, monkeypatch):
    first = register(client).json()
    second = client.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}).json()
    travel(monkeypatch, 11)
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}), 401, "refresh_reused")
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": second["refresh_token"]}), 401, "invalid_token")


# test_refresh_reuse_grace — повтор в первые 10 секунд (две вкладки) не отзывает цепочку
def test_refresh_reuse_grace(client):
    first = register(client).json()
    second = client.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}).json()
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": first["refresh_token"]}), 401, "invalid_token")
    assert client.post("/api/v1/auth/refresh", json={"refresh_token": second["refresh_token"]}).status_code == 200


# test_refresh_errors — неизвестный токен: invalid_token, нет поля: invalid_request, просроченный: invalid_token
def test_refresh_errors(client, monkeypatch):
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": "unknown"}), 401, "invalid_token")
    assert_error(client.post("/api/v1/auth/refresh", json={}), 400, "invalid_request")
    assert_error(client.post("/api/v1/auth/refresh"), 400, "invalid_request")
    token = register(client).json()["refresh_token"]
    travel(monkeypatch, 31 * 24 * 3600)
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": token}), 401, "invalid_token")


# test_logout — logout отзывает цепочку; неизвестный токен и пустое тело тоже 204
def test_logout(client):
    body = register(client).json()
    refreshed = client.post("/api/v1/auth/refresh", json={"refresh_token": body["refresh_token"]}).json()
    assert client.post("/api/v1/auth/logout", json={"refresh_token": refreshed["refresh_token"]}).status_code == 204
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": refreshed["refresh_token"]}), 401, "invalid_token")
    assert client.post("/api/v1/auth/logout", json={"refresh_token": "unknown"}).status_code == 204
    assert client.post("/api/v1/auth/logout").status_code == 204


# test_web_cookie_flow — сайт: refresh только в cookie с нужными атрибутами, в теле его нет
def test_web_cookie_flow(client):
    response = register(client, headers=WEB)
    assert response.status_code == 201 and "refresh_token" not in response.json()
    cookie = response.headers["set-cookie"]
    for part in ("seriq_refresh=", "HttpOnly", "Secure", "SameSite=strict", "Path=/api/v1/auth", "Max-Age=2592000"):
        assert part.lower() in cookie.lower(), cookie
    token = cookie.split("seriq_refresh=")[1].split(";")[0]
    refreshed = client.post("/api/v1/auth/refresh", headers=WEB, cookies={"seriq_refresh": token})
    assert refreshed.status_code == 200 and "refresh_token" not in refreshed.json()
    new_token = refreshed.headers["set-cookie"].split("seriq_refresh=")[1].split(";")[0]
    assert new_token and new_token != token
    assert client.get("/api/v1/me", headers=bearer(refreshed)).status_code == 200


# test_web_cookie_rules — без заголовка cookie игнорируется, у сайта без cookie 401, logout стирает cookie
def test_web_cookie_rules(client):
    response = register(client, headers={"x-seriq-client": "Web"})
    token = response.headers["set-cookie"].split("seriq_refresh=")[1].split(";")[0]
    assert_error(client.post("/api/v1/auth/refresh", cookies={"seriq_refresh": token}), 400, "invalid_request")
    assert_error(client.post("/api/v1/auth/refresh", headers=WEB), 401, "invalid_token")
    assert_error(client.post("/api/v1/auth/refresh", headers=WEB, json={"refresh_token": token}), 401, "invalid_token")
    out = client.post("/api/v1/auth/logout", headers=WEB, cookies={"seriq_refresh": token})
    assert out.status_code == 204 and "max-age=0" in out.headers["set-cookie"].lower()
    assert_error(client.post("/api/v1/auth/refresh", headers=WEB, cookies={"seriq_refresh": token}), 401, "invalid_token")


# test_login_delay — после 5 неудач подряд вход закрыт на минуту даже с верным паролем, потом открывается и сбрасывает счётчик
def test_login_delay(client, monkeypatch, db):
    register(client)
    for _ in range(5):
        assert_error(login(client, password="wrong password 1"), 401, "invalid_credentials")
    blocked = login(client)
    assert_error(blocked, 429, "rate_limited")
    assert blocked.headers["retry-after"] == "60"
    travel(monkeypatch, 61)
    assert login(client).status_code == 200
    assert db.scalar(select(func.count()).select_from(LoginFailure)) == 0


# test_login_delay_growth — задержка по числу неудач: 60, 120, 240, 480, 900 секунд и не больше
@pytest.mark.parametrize(("failures", "delay"), [(5, 60), (6, 120), (7, 240), (8, 480), (9, 900), (12, 900)])
def test_login_delay_growth(client, db, failures, delay):
    row = LoginFailure(login_key="anna_k", failed_count=failures - 1, updated_at=utc_now())
    db.add(row)
    db.commit()
    assert_error(login(client, password="wrong password 1"), 401, "invalid_credentials")
    db.refresh(row)
    assert row.failed_count == failures
    assert abs((row.blocked_until - utc_now()).total_seconds() - delay) < 5


# test_login_block_unknown_login — несуществующий логин блокируется так же, как существующий
def test_login_block_unknown_login(client):
    for _ in range(5):
        assert_error(login(client, "nobody", "wrong password 1"), 401, "invalid_credentials")
    assert_error(login(client, "nobody", "wrong password 1"), 429, "rate_limited")
    register(client)
    for _ in range(5):
        login(client, password="wrong password 1")
    assert_error(login(client, "ANNA_K"), 429, "rate_limited")


# test_login_ip_limit — с одного адреса не больше 20 попыток входа за 10 минут
def test_login_ip_limit(client, monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(ratelimit, "clock", lambda: now[0])
    for i in range(20):
        assert login(client, f"user{i:03d}", "wrong password 1").status_code == 401
    limited = login(client, "user999", "wrong password 1")
    assert_error(limited, 429, "rate_limited")
    assert 1 <= int(limited.headers["retry-after"]) <= 600
    now[0] += 601
    assert login(client, "user998", "wrong password 1").status_code == 401


# test_register_ip_limit — с одного адреса не больше 5 регистраций в час
def test_register_ip_limit(client, monkeypatch):
    now = [1000.0]
    monkeypatch.setattr(ratelimit, "clock", lambda: now[0])
    for i in range(5):
        assert register(client, f"user_{i}").status_code == 201
    assert_error(register(client, "user_9"), 429, "rate_limited")
    now[0] += 3601
    assert register(client, "user_9").status_code == 201


# request_with — запрос для проверки client_ip с адресом прокси peer и заголовком X-Forwarded-For
def request_with(peer, forwarded=None):
    headers = [(b"x-forwarded-for", forwarded.encode())] if forwarded else []
    return Request({"type": "http", "headers": headers, "client": (peer, 1234)})


# test_client_ip — X-Forwarded-For верится только от частной сети, берётся первый публичный адрес справа
@pytest.mark.parametrize(
    ("peer", "forwarded", "expected"),
    [
        ("10.0.0.5", "93.184.216.34", "93.184.216.34"),
        ("172.18.0.3", "93.184.216.34, 172.18.0.2", "93.184.216.34"),
        ("172.18.0.3", "1.1.1.1, 93.184.216.34, 10.0.0.1", "93.184.216.34"),
        ("8.8.4.4", "1.1.1.1", "8.8.4.4"),
        ("10.0.0.5", None, "10.0.0.5"),
        ("10.0.0.5", "garbage, 10.0.0.1", "10.0.0.5"),
    ],
)
def test_client_ip(peer, forwarded, expected):
    assert ratelimit.client_ip(request_with(peer, forwarded)) == expected


# test_ip_limit_uses_forwarded_client — разные клиенты за прокси считаются отдельно, подделка в начале заголовка не помогает
def test_ip_limit_uses_forwarded_client(accounts_env):
    proxy = make_client("172.18.0.3")
    for i in range(5):
        assert register(proxy, f"user_{i}", headers={"X-Forwarded-For": "93.184.216.34"}).status_code == 201
    assert_error(register(proxy, "user_9", headers={"X-Forwarded-For": "93.184.216.34"}), 429, "rate_limited")
    assert_error(register(proxy, "user_9", headers={"X-Forwarded-For": "1.1.1.1, 93.184.216.34"}), 429, "rate_limited")
    assert register(proxy, "user_9", headers={"X-Forwarded-For": "93.184.216.35"}).status_code == 201


# test_delete_account — удаление с паролем стирает пользователя, токены и счётчики; другой пользователь не затронут
def test_delete_account(client, db):
    keep = register(client, "keeper_1").json()
    mine = register(client, "anna_k").json()
    client.post("/api/v1/auth/refresh", json={"refresh_token": mine["refresh_token"]})
    login(client, password="wrong password 1")
    response = client.request("DELETE", "/api/v1/me", json={"password": PASSWORD}, headers={"Authorization": f"Bearer {mine['access_token']}"})
    assert response.status_code == 204 and response.content == b""
    db.expire_all()
    assert [u.login for u in db.scalars(select(User))] == ["keeper_1"]
    assert {t.user_id for t in db.scalars(select(RefreshToken))} == {keep["user"]["id"]}
    assert db.scalar(select(func.count()).select_from(LoginFailure)) == 0
    assert_error(client.get("/api/v1/me", headers={"Authorization": f"Bearer {mine['access_token']}"}), 401, "invalid_token")
    assert_error(login(client), 401, "invalid_credentials")
    assert_error(client.post("/api/v1/auth/refresh", json={"refresh_token": mine["refresh_token"]}), 401, "invalid_token")
    assert client.get("/api/v1/me", headers={"Authorization": f"Bearer {keep['access_token']}"}).status_code == 200


# test_delete_account_wrong_password — неверный пароль даёт 403, аккаунт остаётся, неудачи считаются как при входе
def test_delete_account_wrong_password(client, db):
    token = register(client).json()["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    for _ in range(5):
        assert_error(client.request("DELETE", "/api/v1/me", json={"password": "wrong password 1"}, headers=headers), 403, "invalid_credentials")
    assert_error(client.request("DELETE", "/api/v1/me", json={"password": PASSWORD}, headers=headers), 429, "rate_limited")
    assert db.scalar(select(func.count()).select_from(User)) == 1


# test_delete_account_web — у сайта удаление стирает cookie
def test_delete_account_web(client):
    response = register(client, headers=WEB)
    out = client.request("DELETE", "/api/v1/me", json={"password": PASSWORD}, headers={**bearer(response), **WEB})
    assert out.status_code == 204 and "max-age=0" in out.headers["set-cookie"].lower()


# test_delete_needs_token_and_password — без токена 401, без пароля в теле 400
def test_delete_needs_token_and_password(client):
    token = register(client).json()["access_token"]
    assert_error(client.request("DELETE", "/api/v1/me", json={"password": PASSWORD}), 401, "invalid_token")
    assert_error(client.request("DELETE", "/api/v1/me", json={}, headers={"Authorization": f"Bearer {token}"}), 400, "invalid_request")


# test_secrets_not_in_logs — пароль и токены не попадают ни в журнал, ни в тексты ошибок
def test_secrets_not_in_logs(client, caplog, monkeypatch):
    caplog.set_level(logging.DEBUG)
    secret_password = "very-secret-pass-12345"
    body = register(client, "anna_k", secret_password).json()
    wrong = login(client, "anna_k", "other-secret-pass-999")
    login(client, "anna_k", secret_password)
    client.post("/api/v1/auth/refresh", json={"refresh_token": body["refresh_token"]})
    client.request("DELETE", "/api/v1/me", json={"password": "bad-secret-pass-000"}, headers={"Authorization": f"Bearer {body['access_token']}"})
    monkeypatch.setattr(accounts, "register", lambda *a, **k: (_ for _ in ()).throw(RuntimeError("boom")))
    crash = register(client, "other_user", "crash-secret-pass-111")
    assert crash.status_code == 500
    for value in (secret_password, "other-secret-pass-999", "bad-secret-pass-000", "crash-secret-pass-111", body["access_token"], body["refresh_token"]):
        assert value not in caplog.text and value not in wrong.text and value not in crash.text


# test_hash_slots_limit — одновременно считается не больше двух хэшей
def test_hash_slots_limit(monkeypatch):
    state = {"now": 0, "peak": 0}
    lock = threading.Lock()

    # SlowHasher — хэшер, который помнит, сколько вызовов идёт одновременно
    class SlowHasher:
        # hash — имитирует долгий хэш
        def hash(self, password):
            with lock:
                state["now"] += 1
                state["peak"] = max(state["peak"], state["now"])
            time.sleep(0.05)
            with lock:
                state["now"] -= 1
            return "hash"

    monkeypatch.setattr(passwords, "HASHER", SlowHasher())
    threads = [threading.Thread(target=passwords.hash_password, args=("x" * 12,)) for _ in range(8)]
    [t.start() for t in threads]
    [t.join() for t in threads]
    assert state["peak"] == passwords.MAX_HASHES == 2


# test_busy_when_slots_taken — если места заняты слишком долго, отвечаем 503 busy
def test_busy_when_slots_taken(client, monkeypatch):
    monkeypatch.setattr(passwords, "WAIT_SECONDS", 0.05)
    for _ in range(passwords.MAX_HASHES):
        assert passwords.slots.acquire(blocking=False)
    try:
        assert_error(register(client), 503, "busy")
    finally:
        for _ in range(passwords.MAX_HASHES):
            passwords.slots.release()


# test_rehash_on_login — после входа хэш заменяется, если параметры хэширования новее
def test_rehash_on_login(client, db, monkeypatch):
    register(client)
    old = db.scalar(select(User)).password_hash
    monkeypatch.setattr(passwords, "HASHER", PasswordHasher(time_cost=2, memory_cost=8, parallelism=1))
    assert login(client).status_code == 200
    db.expire_all()
    new = db.scalar(select(User)).password_hash
    assert new != old and "t=2" in new and login(client).status_code == 200


# test_real_argon2_parameters — рабочие параметры: argon2id, 64 МиБ, 3 прохода, 1 поток
def test_real_argon2_parameters():
    assert passwords.PARAMS == {"time_cost": 3, "memory_cost": 65536, "parallelism": 1}
    hasher = PasswordHasher(**passwords.PARAMS)
    assert hasher.hash("x" * 12).startswith("$argon2id$v=19$m=65536,t=3,p=1$")


# test_migrations_match_models — после миграций схема совпадает с моделями
def test_migrations_match_models(db_url):
    engine = make_engine(db_url)
    with engine.connect() as connection:
        context = MigrationContext.configure(connection, opts={"compare_type": True})
        assert compare_metadata(context, Base.metadata) == []
    engine.dispose()
