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
