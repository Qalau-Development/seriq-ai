from fastapi import APIRouter

from app.core.config import API_VERSION, get_settings
from app.schemas.analysis import HealthResponse

router = APIRouter()


# GET /api/v1/health — проверка, что бэкенд работает
@router.get("/health", response_model=HealthResponse)
def health() -> HealthResponse:
    return HealthResponse(status="ok", mode=get_settings().mode, version=API_VERSION)
