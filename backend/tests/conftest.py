from pathlib import Path

import pytest
from alembic import command
from alembic.config import Config

BACKEND_DIR = Path(__file__).resolve().parents[1]


# migrate — применяет миграции Alembic к SQLite-файлу по адресу url
def migrate(url: str) -> None:
    config = Config(str(BACKEND_DIR / "alembic.ini"))
    config.set_main_option("script_location", str(BACKEND_DIR / "alembic"))
    config.set_main_option("sqlalchemy.url", url.replace("%", "%%"))
    command.upgrade(config, "head")


# db_url — адрес пустой SQLite-базы с применёнными миграциями во временной папке
@pytest.fixture
def db_url(tmp_path_factory) -> str:
    url = f"sqlite:///{tmp_path_factory.mktemp('db') / 'seriq.db'}"
    migrate(url)
    return url


# secret — ключ подписи токенов для тестов аккаунтов
SECRET = "test-secret-test-secret-test-secret-0123456789"


# fast_hasher — быстрый argon2 в тестах, настоящие параметры проверяет отдельный тест
@pytest.fixture(autouse=True)
def fast_hasher(monkeypatch):
    from argon2 import PasswordHasher

    from app.services import passwords

    monkeypatch.setattr(passwords, "HASHER", PasswordHasher(time_cost=1, memory_cost=8, parallelism=1))


# reset_limits — пустые счётчики лимитов по IP перед каждым тестом
@pytest.fixture(autouse=True)
def reset_limits():
    from app.services import ratelimit

    ratelimit.login_limiter.reset()
    ratelimit.register_limiter.reset()


# accounts_env — режим mock, база из db_url и ключ подписи в окружении
@pytest.fixture
def accounts_env(monkeypatch, db_url) -> str:
    monkeypatch.setenv("SERIQ_MODE", "mock")
    monkeypatch.setenv("SERIQ_DATABASE_URL", db_url)
    monkeypatch.setenv("SERIQ_AUTH_SECRET", SECRET)
    return db_url
