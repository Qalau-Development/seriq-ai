from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy.orm import Session

from app.api.deps import current_user, get_db
from app.api.routes.auth import ERRORS
from app.db.models import User
from app.schemas.analysis import Exercise
from app.schemas.history import SessionIn, SessionList, SessionListItem, SessionOut, SessionSummary
from app.services import history

router = APIRouter()


# PUT /api/v1/sessions/{session_id} — идемпотентно сохраняет занятие с попытками
@router.put("/sessions/{session_id}", response_model=SessionOut, responses=ERRORS)
def put_session(session_id: str, body: SessionIn, user: User = Depends(current_user), db: Session = Depends(get_db)) -> SessionOut:
    return history.save_session(db, user, history.normalize_id(session_id, "session_id"), body)


# GET /api/v1/sessions — список занятий пользователя, новые первыми, постранично
@router.get("/sessions", response_model=SessionList, responses=ERRORS)
def list_sessions(
    exercise: Exercise | None = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    cursor: str | None = None,
    user: User = Depends(current_user),
    db: Session = Depends(get_db),
) -> SessionList:
    page, next_cursor = history.list_sessions(db, user, exercise, limit, cursor)
    items = [
        SessionListItem(
            id=row.id, exercise=row.exercise, started_at=row.started_at, created_at=row.created_at,
            summary=SessionSummary(total=sum(counts.values()), **counts),
        )
        for row, counts in page
    ]
    return SessionList(items=items, next_cursor=next_cursor)


# GET /api/v1/sessions/{session_id} — занятие со всеми попытками и рядами
@router.get("/sessions/{session_id}", response_model=SessionOut, responses=ERRORS)
def get_session(session_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)) -> SessionOut:
    row = history.get_session(db, user, history.normalize_id(session_id, "session_id"))
    return history.session_to_out(db, row)


# DELETE /api/v1/sessions/{session_id} — удаляет одно занятие
@router.delete("/sessions/{session_id}", status_code=204, responses=ERRORS)
def delete_session(session_id: str, user: User = Depends(current_user), db: Session = Depends(get_db)) -> Response:
    history.delete_session(db, user, history.normalize_id(session_id, "session_id"))
    return Response(status_code=204)


# DELETE /api/v1/sessions — удаляет всю историю пользователя
@router.delete("/sessions", status_code=204, responses=ERRORS)
def delete_all_sessions(user: User = Depends(current_user), db: Session = Depends(get_db)) -> Response:
    history.delete_all_sessions(db, user)
    return Response(status_code=204)
