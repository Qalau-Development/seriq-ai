import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, MetaData
from sqlalchemy.engine import Dialect
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.types import TypeDecorator

NAMING = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}


# Base — общая база моделей с едиными именами ограничений для миграций
class Base(DeclarativeBase):
    metadata = MetaData(naming_convention=NAMING)


# UTCDateTime — время в UTC: в базе без пояса, в коде всегда с поясом, одинаково в SQLite и Postgres
class UTCDateTime(TypeDecorator):
    impl = DateTime
    cache_ok = True

    # process_bind_param — приводит время к UTC перед записью
    def process_bind_param(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        if value is None:
            return None
        if value.tzinfo is None:
            raise ValueError("naive datetime is not allowed")
        return value.astimezone(timezone.utc).replace(tzinfo=None)

    # process_result_value — возвращает время из базы с поясом UTC
    def process_result_value(self, value: datetime | None, dialect: Dialect) -> datetime | None:
        return None if value is None else value.replace(tzinfo=timezone.utc)


# utc_now — текущее время с поясом UTC
def utc_now() -> datetime:
    return datetime.now(timezone.utc)


# new_id — новый UUID строкой (без диалектного типа UUID)
def new_id() -> str:
    return str(uuid.uuid4())
