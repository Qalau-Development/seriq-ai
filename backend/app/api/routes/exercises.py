from fastapi import APIRouter

from app.core.config import get_settings
from app.core.exercises import EXERCISES, measure_meta
from app.schemas.analysis import ExerciseItem
from app.services.engine import engine_catalog

router = APIRouter()


# GET /api/v1/exercises — массив упражнений: что измеряется и готова ли модель
@router.get("/exercises", response_model=list[ExerciseItem])
def list_exercises() -> list[ExerciseItem]:
    if get_settings().mode == "mock":
        items = [{"id": e, "ready": True, "measure": measure_meta(e)} for e in EXERCISES]
    else:
        items = engine_catalog()
    return [ExerciseItem.model_validate(item) for item in items]
