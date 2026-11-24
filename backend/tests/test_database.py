import pytest
from fastapi.testclient import TestClient
from sqlalchemy import text

from app.db.engine import make_engine
from app.main import create_app

ACCOUNT_PREFIXES = ("/api/v1/auth", "/api/v1/me", "/api/v1/sessions", "/api/v1/progress")


# paths — пути, которые приложение отдаёт в схеме OpenAPI
def paths(client: TestClient) -> list[str]:
    return list(client.get("/api/openapi.json").json()["paths"])


# test_starts_without_database — без SERIQ_DATABASE_URL сервер работает как раньше: маршрутов аккаунтов нет, в health нет поля database
def test_starts_without_database(monkeypatch):
    monkeypatch.setenv("SERIQ_MODE", "mock")
    monkeypatch.delenv("SERIQ_DATABASE_URL", raising=False)
    client = TestClient(create_app(), raise_server_exceptions=False)
    assert client.get("/api/v1/health").json() == {"status": "ok", "mode": "mock", "version": "0.1.0"}
    assert not [p for p in paths(client) if p.startswith(ACCOUNT_PREFIXES)]
    for path in ("/api/v1/auth/login", "/api/v1/me", "/api/v1/sessions", "/api/v1/progress/summary"):
        assert client.get(path).status_code == 404


# test_empty_database_url_is_off — пустое значение переменной считается «база выключена»
def test_empty_database_url_is_off(monkeypatch):
    monkeypatch.setenv("SERIQ_DATABASE_URL", "")
    client = TestClient(create_app())
    assert "database" not in client.get("/api/v1/health").json()


# test_health_with_database — при заданной базе health показывает database ok
def test_health_with_database(accounts_env):
    client = TestClient(create_app())
    assert client.get("/api/v1/health").json() == {"status": "ok", "mode": "mock", "version": "0.1.0", "database": "ok"}


# test_health_database_unavailable — если база недоступна, health отвечает 200 и database unavailable
def test_health_database_unavailable(monkeypatch, tmp_path):
    monkeypatch.setenv("SERIQ_AUTH_SECRET", "x" * 40)
    monkeypatch.setenv("SERIQ_DATABASE_URL", f"sqlite:///{tmp_path / 'missing-dir' / 'seriq.db'}")
    client = TestClient(create_app())
    response = client.get("/api/v1/health")
    assert response.status_code == 200 and response.json()["database"] == "unavailable"


# test_database_needs_secret — с базой без SERIQ_AUTH_SECRET сервер не запускается
def test_database_needs_secret(monkeypatch, db_url):
    monkeypatch.setenv("SERIQ_DATABASE_URL", db_url)
    monkeypatch.delenv("SERIQ_AUTH_SECRET", raising=False)
    with pytest.raises(RuntimeError, match="SERIQ_AUTH_SECRET"):
        create_app()
    monkeypatch.setenv("SERIQ_AUTH_SECRET", "short")
    with pytest.raises(RuntimeError, match="SERIQ_AUTH_SECRET"):
        create_app()


# test_sqlite_pragmas — у соединения включены внешние ключи и WAL
def test_sqlite_pragmas(db_url):
    engine = make_engine(db_url)
    with engine.connect() as connection:
        assert connection.execute(text("PRAGMA foreign_keys")).scalar() == 1
        assert connection.execute(text("PRAGMA journal_mode")).scalar() == "wal"
    engine.dispose()


# test_analysis_does_not_need_database — анализ работает и когда база включена, и когда она недоступна
@pytest.mark.parametrize("broken", [False, True])
def test_analysis_does_not_need_database(monkeypatch, tmp_path, accounts_env, broken):
    if broken:
        monkeypatch.setenv("SERIQ_DATABASE_URL", f"sqlite:///{tmp_path / 'nope' / 'x.db'}")
    client = TestClient(create_app())
    mp4 = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64
    assert client.post("/api/v1/analysis", files={"video": ("rep.mp4", mp4, "video/mp4")}).status_code == 200
