import hashlib
import secrets
from datetime import datetime, timedelta

import jwt

from app.core.errors import AppError

ACCESS_TTL = timedelta(minutes=15)
REFRESH_TTL = timedelta(days=30)


# create_access_token — подписанный access-токен на 15 минут для пользователя
def create_access_token(user_id: str, secret: str, now: datetime) -> str:
    issued = int(now.timestamp())
    claims = {"sub": user_id, "iat": issued, "exp": issued + int(ACCESS_TTL.total_seconds())}
    return jwt.encode(claims, secret, algorithm="HS256")


# read_access_token — id пользователя из токена; истёкший даёт token_expired, любой другой плохой invalid_token
def read_access_token(token: str, secret: str) -> str:
    try:
        claims = jwt.decode(token, secret, algorithms=["HS256"], options={"require": ["exp", "iat", "sub"]})
    except jwt.ExpiredSignatureError as exc:
        raise AppError("token_expired", 401, "The access token has expired") from exc
    except jwt.PyJWTError as exc:
        raise AppError("invalid_token", 401, "The token is not valid") from exc
    return str(claims["sub"])


# new_refresh_token — случайный refresh-токен на 256 бит
def new_refresh_token() -> str:
    return secrets.token_urlsafe(32)


# hash_refresh_token — SHA-256 токена: в базе хранится только он
def hash_refresh_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()
