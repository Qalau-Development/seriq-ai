import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.api.routes import analysis, health
from app.core.config import API_VERSION, get_settings
from app.core.errors import AppError
from app.services.analysis import warmup_model

logger = logging.getLogger("seriq")


# error_response — ответ об ошибке в едином формате
def error_response(status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(status_code=status_code, content={"status": "error", "error": {"code": code, "message": message}})


# handle_app_error — превращает AppError в единый формат
def handle_app_error(request: Request, exc: AppError) -> JSONResponse:
    return error_response(exc.http_status, exc.code, exc.message)


# handle_validation_error — отсутствие поля video даёт 400 missing_video
def handle_validation_error(request: Request, exc: RequestValidationError) -> JSONResponse:
    return error_response(400, "missing_video", "The 'video' field is required")


# handle_unexpected_error — любая другая ошибка даёт 500 internal_error
def handle_unexpected_error(request: Request, exc: Exception) -> JSONResponse:
    logger.exception("Unhandled error", exc_info=exc)
    return error_response(500, "internal_error", "Internal server error")


# create_app — собирает приложение FastAPI
def create_app() -> FastAPI:
    if get_settings().mode == "model":
        warmup_model()
    app = FastAPI(title="SerIQ API", version=API_VERSION, docs_url="/api/docs", openapi_url="/api/openapi.json")
    app.include_router(health.router, prefix="/api/v1")
    app.include_router(analysis.router, prefix="/api/v1")
    app.add_exception_handler(AppError, handle_app_error)
    app.add_exception_handler(RequestValidationError, handle_validation_error)
    app.add_exception_handler(Exception, handle_unexpected_error)
    return app


app = create_app()
