from fastapi import APIRouter

from app.core.config import get_settings
from app.core.exercises import EXERCISES, measure_meta
from app.schemas.analysis import ExercisesResponse
from app.services.engine import engine_catalog

router = APIRouter()


# GET /api/v1/exercises — каталог упражнений: готовность модели и что измеряется
@router.get("/exercises", response_model=ExercisesResponse)
def list_exercises() -> ExercisesResponse:
    if get_settings().mode == "mock":
        items = [{"id": e, "ready": True, "measure": measure_meta(e)} for e in EXERCISES]
    else:
        items = engine_catalog()
    return ExercisesResponse(status="ok", exercises=items)
