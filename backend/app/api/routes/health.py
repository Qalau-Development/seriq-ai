from fastapi import APIRouter, Request

from app.core.config import API_VERSION, get_settings
from app.db.engine import database_ok
from app.schemas.analysis import HealthResponse

router = APIRouter()


# GET /api/v1/health — проверка, что бэкенд работает; поле database только при включённой базе
@router.get("/health", response_model=HealthResponse, response_model_exclude_none=True)
def health(request: Request) -> HealthResponse:
    engine = getattr(request.app.state, "engine", None)
    database = None if engine is None else ("ok" if database_ok(engine) else "unavailable")
    return HealthResponse(status="ok", mode=get_settings().mode, version=API_VERSION, database=database)
