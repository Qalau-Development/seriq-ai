from collections.abc import Iterator

from fastapi import Depends, Header, Request
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.core.errors import AppError
from app.db.models import User
from app.services.tokens import read_access_token


# get_db — сессия базы на один запрос
def get_db(request: Request) -> Iterator[Session]:
    with request.app.state.session_factory() as session:
        yield session


# auth_secret — ключ подписи токенов из окружения
def auth_secret() -> str:
    secret = get_settings().auth_secret
    if not secret:
        raise AppError("internal_error", 500, "Accounts are not configured")
    return secret


# current_user — пользователь по заголовку Authorization: Bearer; нет токена или он плохой — invalid_token, истёк — token_expired
def current_user(authorization: str | None = Header(default=None), db: Session = Depends(get_db)) -> User:
    scheme, _, token = (authorization or "").partition(" ")
    if scheme.lower() != "bearer" or not token.strip():
        raise AppError("invalid_token", 401, "Authorization header with a Bearer token is required")
    user = db.get(User, read_access_token(token.strip(), auth_secret()))
    if user is None:
        raise AppError("invalid_token", 401, "The token is not valid")
    return user
