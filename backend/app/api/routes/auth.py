from fastapi import APIRouter, Body, Depends, Request, Response
from sqlalchemy.orm import Session

from app.api.deps import auth_secret, get_db
from app.core.errors import AppError
from app.schemas.accounts import AuthResponse, Credentials, RefreshBody, TokenPair, UserOut
from app.schemas.analysis import ErrorResponse
from app.services import accounts
from app.services.ratelimit import LOGIN_PER_IP, REGISTER_PER_IP, limit_ip, login_limiter, register_limiter
from app.services.tokens import REFRESH_TTL

router = APIRouter(prefix="/auth")

COOKIE_NAME = "seriq_refresh"
COOKIE_PATH = "/api/v1/auth"
ERRORS = {code: {"model": ErrorResponse} for code in (400, 401, 403, 409, 429, 503)}


# is_web — запрос от сайта: заголовок X-SerIQ-Client: web
def is_web(request: Request) -> bool:
    return request.headers.get("x-seriq-client", "").strip().lower() == "web"


# set_refresh_cookie — кладёт refresh-токен сайта в httpOnly cookie
def set_refresh_cookie(response: Response, token: str) -> None:
    response.set_cookie(
        COOKIE_NAME,
        token,
        max_age=int(REFRESH_TTL.total_seconds()),
        path=COOKIE_PATH,
        httponly=True,
        secure=True,
        samesite="strict",
    )


# clear_refresh_cookie — стирает cookie с refresh-токеном
def clear_refresh_cookie(response: Response) -> None:
    response.delete_cookie(COOKIE_NAME, path=COOKIE_PATH, httponly=True, secure=True, samesite="strict")


# refresh_for_client — для сайта refresh уходит в cookie, для приложения остаётся в теле
def refresh_for_client(request: Request, response: Response, refresh: str) -> str | None:
    if is_web(request):
        set_refresh_cookie(response, refresh)
        return None
    return refresh


# token_from_request — refresh-токен: у сайта только из cookie, у приложения только из тела
def token_from_request(request: Request, body: RefreshBody | None) -> str | None:
    if is_web(request):
        return request.cookies.get(COOKIE_NAME)
    return body.refresh_token if body else None


# POST /api/v1/auth/register — создаёт аккаунт и сразу выдаёт токены
@router.post("/register", status_code=201, response_model=AuthResponse, response_model_exclude_none=True, responses=ERRORS)
def register(body: Credentials, request: Request, response: Response, db: Session = Depends(get_db)) -> AuthResponse:
    limit_ip(register_limiter, request, REGISTER_PER_IP)
    user = accounts.register(db, body.login, body.password)
    access, refresh = accounts.issue_tokens(db, user, auth_secret())
    return AuthResponse(
        user=UserOut.model_validate(user, from_attributes=True),
        access_token=access,
        refresh_token=refresh_for_client(request, response, refresh),
        expires_in=accounts.expires_in(),
    )


# POST /api/v1/auth/login — вход по логину и паролю
@router.post("/login", response_model=AuthResponse, response_model_exclude_none=True, responses=ERRORS)
def login(body: Credentials, request: Request, response: Response, db: Session = Depends(get_db)) -> AuthResponse:
    limit_ip(login_limiter, request, LOGIN_PER_IP)
    user = accounts.authenticate(db, body.login, body.password)
    access, refresh = accounts.issue_tokens(db, user, auth_secret())
    return AuthResponse(
        user=UserOut.model_validate(user, from_attributes=True),
        access_token=access,
        refresh_token=refresh_for_client(request, response, refresh),
        expires_in=accounts.expires_in(),
    )


# POST /api/v1/auth/refresh — меняет refresh-токен на новую пару
@router.post("/refresh", response_model=TokenPair, response_model_exclude_none=True, responses=ERRORS)
def refresh(request: Request, response: Response, body: RefreshBody | None = Body(default=None), db: Session = Depends(get_db)) -> TokenPair:
    token = token_from_request(request, body)
    if token is None:
        if is_web(request):
            raise AppError("invalid_token", 401, "The refresh cookie is missing")
        raise AppError("invalid_request", 400, "The 'refresh_token' field is required")
    _, access, new_refresh = accounts.rotate_refresh(db, token, auth_secret())
    return TokenPair(access_token=access, refresh_token=refresh_for_client(request, response, new_refresh), expires_in=accounts.expires_in())


# POST /api/v1/auth/logout — отзывает цепочку refresh-токена, всегда 204
@router.post("/logout", status_code=204, responses=ERRORS)
def logout(request: Request, body: RefreshBody | None = Body(default=None), db: Session = Depends(get_db)) -> Response:
    accounts.logout(db, token_from_request(request, body))
    response = Response(status_code=204)
    if is_web(request):
        clear_refresh_cookie(response)
    return response
