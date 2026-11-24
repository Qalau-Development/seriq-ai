from datetime import datetime

from pydantic import BaseModel


# Credentials — логин и пароль для регистрации и входа
class Credentials(BaseModel):
    login: str
    password: str


# RefreshBody — тело refresh и logout; у мобильного приложения токен в теле, у сайта в cookie
class RefreshBody(BaseModel):
    refresh_token: str | None = None


# DeleteAccountBody — пароль-подтверждение удаления аккаунта
class DeleteAccountBody(BaseModel):
    password: str


# UserOut — пользователь в ответах
class UserOut(BaseModel):
    id: str
    login: str
    created_at: datetime


# TokenPair — новая пара токенов; у сайта refresh в cookie и в теле его нет
class TokenPair(BaseModel):
    access_token: str
    refresh_token: str | None = None
    expires_in: int


# AuthResponse — ответ регистрации и входа: пользователь и токены
class AuthResponse(TokenPair):
    user: UserOut
