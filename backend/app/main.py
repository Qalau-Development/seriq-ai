import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.api.routes import analysis, auth, exercises, health, me, progress, sessions
from app.core.config import API_VERSION, get_settings
from app.core.errors import AppError
from app.db.engine import make_engine, make_session_factory
from app.services.analysis import warmup_model

logger = logging.getLogger("seriq")
MIN_SECRET_LENGTH = 32


# error_response — ответ об ошибке в едином формате
def error_response(status_code: int, code: str, message: str, headers: dict[str, str] | None = None) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content={"status": "error", "error": {"code": code, "message": message}},
        headers=headers,
    )


# handle_app_error — превращает AppError в единый формат
def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
    return error_response(exc.http_status, exc.code, exc.message, exc.headers)


# handle_validation_error — для анализа 400 missing_video, для остальных роутов 400 invalid_request без значений из запроса
def handle_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    if request.url.path == "/api/v1/analysis":
        return error_response(400, "missing_video", "The 'video' field is required")
    return error_response(400, "invalid_request", "The request has a wrong format")


# handle_unexpected_error — любая другая ошибка даёт 500 internal_error
def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled error", exc_info=exc)
    return error_response(500, "internal_error", "Internal server error")


# lifespan — при остановке закрывает соединения с базой, если она включена
@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    yield
    engine = getattr(app.state, "engine", None)
    if engine is not None:
        engine.dispose()


# create_app — собирает приложение FastAPI; база и маршруты аккаунтов подключаются только при SERIQ_DATABASE_URL
def create_app() -> FastAPI:
    settings = get_settings()
    if settings.mode == "model":
        warmup_model()
    app = FastAPI(title="SerIQ API", version=API_VERSION, docs_url="/api/docs", openapi_url="/api/openapi.json", lifespan=lifespan)
    if settings.database_url:
        if not settings.auth_secret or len(settings.auth_secret) < MIN_SECRET_LENGTH:
            raise RuntimeError(f"SERIQ_AUTH_SECRET of at least {MIN_SECRET_LENGTH} characters is required when SERIQ_DATABASE_URL is set")
        app.state.engine = make_engine(settings.database_url)
        app.state.session_factory = make_session_factory(app.state.engine)
        app.include_router(auth.router, prefix="/api/v1")
        app.include_router(me.router, prefix="/api/v1")
        app.include_router(sessions.router, prefix="/api/v1")
        app.include_router(progress.router, prefix="/api/v1")
    app.include_router(health.router, prefix="/api/v1")
    app.include_router(exercises.router, prefix="/api/v1")
    app.include_router(analysis.router, prefix="/api/v1")
    app.add_exception_handler(AppError, handle_app_error)
    app.add_exception_handler(RequestValidationError, handle_validation_error)
    app.add_exception_handler(Exception, handle_unexpected_error)
    return app


app = create_app()
