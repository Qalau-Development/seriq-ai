import json

import pytest
from fastapi.testclient import TestClient

from app.core.body_limit import LIMITS, MIB, limit_for
from app.main import create_app
from app.services import accounts
from tests.test_accounts import assert_error, bearer, register
from tests.test_history import attempt, new_id, session_body

MP4 = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64


# client — клиент в режиме mock с включённой базой
@pytest.fixture
def client(accounts_env):
    return TestClient(create_app(), raise_server_exceptions=False)


# test_limit_for — лимиты по путям: сессии 2 МиБ, вход, профиль и сводка 1 МиБ, анализ и прочее не ограничиваются здесь
def test_limit_for():
    assert limit_for("/api/v1/sessions") == limit_for("/api/v1/sessions/abc") == 2 * MIB
    for path in ("/api/v1/auth/login", "/api/v1/auth/register", "/api/v1/me", "/api/v1/progress/summary"):
        assert limit_for(path) == MIB
    for path in ("/api/v1/analysis", "/api/v1/health", "/api/v1/exercises", "/api/v1/mesh", "/api/v1/sessionsX"):
        assert limit_for(path) is None
    assert dict(LIMITS)["/api/v1/sessions"] >= 1.3 * MIB


# test_content_length_rejected_before_handler — по Content-Length слишком большое тело отвергается, обработчик не вызывается
def test_content_length_rejected_before_handler(client, monkeypatch):
    called = []
    monkeypatch.setattr(accounts, "authenticate", lambda *a, **k: called.append(1))
    big = b'{"login":"anna_k","password":"' + b"x" * (MIB + 10) + b'"}'
    response = client.post("/api/v1/auth/login", content=big, headers={"content-type": "application/json"})
    assert_error(response, 413, "payload_too_large")
    assert called == []


# test_chunked_body_rejected — без Content-Length тело считается по мере чтения и обрывается на превышении
def test_chunked_body_rejected(client):
    token = bearer(register(client))

    # chunks — тело частями по 256 КиБ, всего больше 2 МиБ
    def chunks():
        yield b'{"exercise":"E02","started_at":"2026-11-25T08:41:03Z","attempts":["'
        for _ in range(10):
            yield b"x" * (256 * 1024)

    response = client.put(f"/api/v1/sessions/{new_id()}", content=chunks(), headers={**token, "content-type": "application/json"})
    assert_error(response, 413, "payload_too_large")
    assert client.get("/api/v1/me", headers=token).status_code == 200


# test_small_routes_limit_one_mib — для входа, профиля и сводки предел 1 МиБ, а для сессий больше
def test_small_routes_limit_one_mib(client):
    token = bearer(register(client))
    body = b'{"password":"' + b"x" * (MIB + 1) + b'"}'
    assert_error(client.request("DELETE", "/api/v1/me", content=body, headers={**token, "content-type": "application/json"}), 413, "payload_too_large")
    medium = session_body([attempt(analysis_id=new_id(), series=[1.0] * 1000) for _ in range(200)])
    size = len(json.dumps(medium).encode())
    assert MIB < size < 2 * MIB
    assert client.put(f"/api/v1/sessions/{new_id()}", json=medium, headers=token).status_code == 200


# test_analysis_not_limited_by_account_limits — загрузка видео больше 2 МиБ проходит, лимит анализа задаёт upload
def test_analysis_not_limited_by_account_limits(client):
    response = client.post("/api/v1/analysis", files={"video": ("rep.mp4", MP4 + b"\x00" * (3 * MIB), "video/mp4")})
    assert response.status_code == 200
