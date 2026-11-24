from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.api.deps import current_user, get_db
from app.api.routes.auth import ERRORS
from app.db.models import User
from app.schemas.analysis import Exercise
from app.schemas.history import ProgressSummary
from app.services import history

router = APIRouter()


# GET /api/v1/progress/summary — сводка прогресса из сохранённых попыток, без оценок выздоровления
@router.get("/progress/summary", response_model=ProgressSummary, responses=ERRORS)
def progress_summary(
    exercise: Exercise | None = None,
    utc_offset_minutes: Annotated[int, Query(ge=-720, le=840)] = 0,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
) -> ProgressSummary:
    return ProgressSummary(**history.progress_summary(db, user, exercise, utc_offset_minutes))
