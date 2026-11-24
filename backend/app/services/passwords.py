import threading
from collections.abc import Iterator
from contextlib import contextmanager

from argon2 import PasswordHasher
from argon2.exceptions import InvalidHashError, VerificationError

from app.core.errors import AppError

# argon2id: 64 МиБ, 3 прохода, 1 поток; подбирается замером на сервере (память одновременно: не больше MAX_HASHES × 64 МиБ)
PARAMS = {"time_cost": 3, "memory_cost": 65536, "parallelism": 1}
HASHER = PasswordHasher(**PARAMS)
MAX_HASHES = 2
WAIT_SECONDS = 10
MIN_LENGTH = 10
MAX_LENGTH = 128

slots = threading.BoundedSemaphore(MAX_HASHES)
dummy_hashes: dict[int, str] = {}


# hash_slot — занимает одно из мест для тяжёлого хэширования, при долгом ожидании отвечает 503 busy
@contextmanager
def hash_slot() -> Iterator[None]:
    if not slots.acquire(timeout=WAIT_SECONDS):
        raise AppError("busy", 503, "The server is busy, retry in a few seconds")
    try:
        yield
    finally:
        slots.release()


# hash_password — argon2id-хэш пароля, соль и параметры внутри строки
def hash_password(password: str) -> str:
    with hash_slot():
        return HASHER.hash(password)


# verify_password — проверяет пароль; вторым значением новый хэш, если параметры хэширования устарели
def verify_password(stored_hash: str, password: str) -> tuple[bool, str | None]:
    with hash_slot():
        try:
            HASHER.verify(stored_hash, password)
        except (VerificationError, InvalidHashError):
            return False, None
        return True, HASHER.hash(password) if HASHER.check_needs_rehash(stored_hash) else None


# dummy_hash — фиктивный хэш с текущими параметрами: по нему считаем пароль для несуществующего логина, чтобы время ответа не выдавало логин
def dummy_hash() -> str:
    key = id(HASHER)
    if key not in dummy_hashes:
        dummy_hashes[key] = hash_password("dummy-password-for-timing")
    return dummy_hashes[key]


# check_password_rules — правила пароля: длина 10–128 и без логина внутри; возвращает текст нарушения или None
def check_password_rules(password: str, login: str) -> str | None:
    if len(password) < MIN_LENGTH:
        return f"Password must be at least {MIN_LENGTH} characters"
    if len(password) > MAX_LENGTH:
        return f"Password must be at most {MAX_LENGTH} characters"
    if login.lower() in password.lower():
        return "Password must not contain the login"
    return None
