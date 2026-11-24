from sqlalchemy import Engine, create_engine, event, text
from sqlalchemy.orm import Session, sessionmaker


# make_engine — синхронный движок по SERIQ_DATABASE_URL; для SQLite включает WAL и внешние ключи
def make_engine(url: str) -> Engine:
    if url.startswith("sqlite"):
        engine = create_engine(url, connect_args={"check_same_thread": False})
        event.listen(engine, "connect", set_sqlite_pragmas)
        return engine
    return create_engine(url, pool_pre_ping=True)


# set_sqlite_pragmas — настройки каждого соединения SQLite: внешние ключи, WAL, ожидание блокировки
def set_sqlite_pragmas(dbapi_connection, connection_record) -> None:
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute("PRAGMA synchronous=NORMAL")
    cursor.execute("PRAGMA busy_timeout=5000")
    cursor.close()


# make_session_factory — фабрика сессий без автоматического сброса после коммита
def make_session_factory(engine: Engine) -> sessionmaker[Session]:
    return sessionmaker(engine, expire_on_commit=False)


# database_ok — база отвечает на простой запрос
def database_ok(engine: Engine) -> bool:
    try:
        with engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return True
    except Exception:
        return False
