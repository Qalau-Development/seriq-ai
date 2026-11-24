import math
import re
import uuid
from datetime import datetime, timedelta

from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.db.base import new_id, utc_now
from app.db.models import LoginFailure, RefreshToken, User
from app.services import passwords
from app.services.ratelimit import rate_limited
from app.services.tokens import (
    ACCESS_TTL,
    REFRESH_TTL,
    create_access_token,
    hash_refresh_token,
    new_refresh_token,
)

LOGIN_RE = re.compile(r"^[A-Za-z0-9._-]{3,32}$")
FREE_FAILURES = 4
MAX_DELAY_SECONDS = 15 * 60
FAILURES_KEEP = timedelta(hours=24)
REUSE_GRACE = timedelta(seconds=10)
KEY_LENGTH = 64


# login_key — ключ логина без учёта регистра, для уникальности и счётчика неудач
def login_key(login: str) -> str:
    return login.lower()[:KEY_LENGTH]


# invalid_credentials — одинаковая ошибка для неверного логина и неверного пароля
def invalid_credentials(status: int = 401) -> AppError:
    return AppError("invalid_credentials", status, "Wrong login or password")


# check_not_blocked — если для логина действует задержка после неудач, отвечает 429 с Retry-After
def check_not_blocked(db: Session, key: str) -> None:
    row = db.get(LoginFailure, key)
    now = utc_now()
    if row and row.blocked_until and row.blocked_until > now:
        raise rate_limited(max(1, math.ceil((row.blocked_until - now).total_seconds())))


# record_failure — считает неудачу по логину: с 5-й подряд задержка 1, 2, 4, 8 минут и до 15 минут
def record_failure(db: Session, key: str) -> None:
    now = utc_now()
    row = db.get(LoginFailure, key)
    if row is None:
        row = LoginFailure(login_key=key, failed_count=0)
        db.add(row)
    elif row.updated_at < now - FAILURES_KEEP:
        row.failed_count = 0
    row.failed_count += 1
    row.updated_at = now
    if row.failed_count > FREE_FAILURES:
        delay = min(MAX_DELAY_SECONDS, 60 * 2 ** (row.failed_count - FREE_FAILURES - 1))
        row.blocked_until = now + timedelta(seconds=delay)
    db.execute(delete(LoginFailure).where(LoginFailure.updated_at < now - FAILURES_KEEP))
    db.commit()


# clear_failures — после успешного входа забывает неудачи по логину
def clear_failures(db: Session, key: str) -> None:
    db.execute(delete(LoginFailure).where(LoginFailure.login_key == key))


# issue_tokens — выдаёт пару токенов; refresh записывается хэшем, просроченные токены пользователя чистятся
def issue_tokens(db: Session, user: User, secret: str, family_id: str | None = None) -> tuple[str, str]:
    now = utc_now()
    refresh = new_refresh_token()
    db.execute(delete(RefreshToken).where(RefreshToken.user_id == user.id, RefreshToken.expires_at < now))
    db.add(
        RefreshToken(
            user_id=user.id,
            family_id=family_id or new_id(),
            token_hash=hash_refresh_token(refresh),
            created_at=now,
            expires_at=now + REFRESH_TTL,
        )
    )
    db.commit()
    return create_access_token(user.id, secret, now), refresh


# expires_in — срок жизни access-токена в секундах
def expires_in() -> int:
    return int(ACCESS_TTL.total_seconds())


# register — создаёт аккаунт по правилам логина и пароля
def register(db: Session, login: str, password: str) -> User:
    if not LOGIN_RE.fullmatch(login):
        raise AppError("invalid_request", 400, "Login must be 3-32 characters: letters, digits, '.', '_', '-'")
    problem = passwords.check_password_rules(password, login)
    if problem:
        raise AppError("weak_password", 400, problem)
    key = login_key(login)
    if db.scalar(select(User.id).where(User.login_key == key)):
        raise AppError("login_taken", 409, "This login is already taken")
    user = User(id=str(uuid.uuid4()), login=login, login_key=key, password_hash=passwords.hash_password(password), created_at=utc_now().replace(microsecond=0))
    db.add(user)
    try:
        db.commit()
    except IntegrityError as exc:
        db.rollback()
        raise AppError("login_taken", 409, "This login is already taken") from exc
    return user


# authenticate — проверяет логин и пароль; неудачи считаются, ответ и время одинаковы для неверного логина и пароля
def authenticate(db: Session, login: str, password: str) -> User:
    key = login_key(login)
    check_not_blocked(db, key)
    user = db.scalar(select(User).where(User.login_key == key))
    if len(password) > passwords.MAX_LENGTH:
        record_failure(db, key)
        raise invalid_credentials()
    ok, new_hash = passwords.verify_password(user.password_hash if user else passwords.dummy_hash(), password)
    if not ok or user is None:
        record_failure(db, key)
        raise invalid_credentials()
    if new_hash:
        user.password_hash = new_hash
    clear_failures(db, key)
    db.commit()
    return user


# confirm_password — подтверждение паролем для действий над своим аккаунтом; неверный пароль считается неудачей входа
def confirm_password(db: Session, user: User, password: str) -> None:
    check_not_blocked(db, user.login_key)
    ok = len(password) <= passwords.MAX_LENGTH and passwords.verify_password(user.password_hash, password)[0]
    if not ok:
        record_failure(db, user.login_key)
        raise invalid_credentials(403)
    clear_failures(db, user.login_key)
    db.commit()


# revoke_family — отзывает все токены цепочки
def revoke_family(db: Session, family_id: str, now: datetime) -> None:
    db.execute(update(RefreshToken).where(RefreshToken.family_id == family_id, RefreshToken.revoked_at.is_(None)).values(revoked_at=now))


# rotate_refresh — меняет refresh-токен на новую пару; повтор уже использованного токена после 10 секунд отзывает всю цепочку
def rotate_refresh(db: Session, raw_token: str, secret: str) -> tuple[User, str, str]:
    now = utc_now()
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(raw_token)))
    if row is None or row.revoked_at is not None or row.expires_at <= now:
        raise AppError("invalid_token", 401, "The refresh token is not valid")
    claimed = db.execute(update(RefreshToken).where(RefreshToken.id == row.id, RefreshToken.used_at.is_(None)).values(used_at=now))
    if claimed.rowcount == 0:
        db.rollback()
        db.refresh(row)
        if row.used_at is not None and now - row.used_at <= REUSE_GRACE:
            raise AppError("invalid_token", 401, "The refresh token was just used, retry with the newest one")
        revoke_family(db, row.family_id, now)
        db.commit()
        raise AppError("refresh_reused", 401, "The refresh token was used again, log in again")
    user = db.get(User, row.user_id)
    if user is None:
        raise AppError("invalid_token", 401, "The refresh token is not valid")
    access, refresh = issue_tokens(db, user, secret, row.family_id)
    return user, access, refresh


# logout — отзывает цепочку токена; неизвестный токен молча игнорируется
def logout(db: Session, raw_token: str | None) -> None:
    if not raw_token:
        return
    row = db.scalar(select(RefreshToken).where(RefreshToken.token_hash == hash_refresh_token(raw_token)))
    if row is not None:
        revoke_family(db, row.family_id, utc_now())
        db.commit()


# delete_account — стирает пользователя и всё, что с ним связано (каскадом в базе)
def delete_account(db: Session, user: User) -> None:
    db.execute(delete(LoginFailure).where(LoginFailure.login_key == user.login_key))
    db.delete(user)
    db.commit()
