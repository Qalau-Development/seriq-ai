import os

from alembic import context
from sqlalchemy import create_engine

import app.db.models  # noqa: F401  модели регистрируются в metadata
from app.db.base import Base

config = context.config
target_metadata = Base.metadata


# database_url — адрес базы: из конфигурации Alembic (тесты) или из SERIQ_DATABASE_URL
def database_url() -> str:
    url = config.get_main_option("sqlalchemy.url") or os.environ.get("SERIQ_DATABASE_URL")
    if not url:
        raise SystemExit("SERIQ_DATABASE_URL is not set")
    return url


# run_migrations — применяет миграции к базе; batch нужен SQLite для ALTER
def run_migrations() -> None:
    engine = create_engine(database_url())
    with engine.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata, render_as_batch=True, compare_type=True)
        with context.begin_transaction():
            context.run_migrations()
    engine.dispose()


run_migrations()
