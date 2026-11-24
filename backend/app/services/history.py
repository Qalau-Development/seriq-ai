import base64
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.errors import AppError
from app.core.exercises import measure_meta
from app.db.base import utc_now
from app.db.models import AttemptRow, SessionRow, User
from app.schemas.history import AttemptIn, AttemptOut, SessionIn, SessionOut

MAX_ATTEMPTS = 200
MAX_VALUES = 1000
MAX_USER_SESSIONS = 1000
MAX_USER_ATTEMPTS = 10000
ACTIVITY_DAYS = 90
POINTS_LIMIT = 100
LABELS = ("complete", "incomplete", "uncertain")


# normalize_id — приводит идентификатор к UUID в нижнем регистре или отвечает invalid_request
def normalize_id(value: str, what: str) -> str:
    try:
        return str(uuid.UUID(value))
    except (ValueError, AttributeError, TypeError) as exc:
        raise AppError("invalid_request", 400, f"{what} must be a UUID") from exc


# too_large — ошибка 413 payload_too_large
def too_large(message: str) -> AppError:
    return AppError("payload_too_large", 413, message)


# check_session_body — правила тела занятия: размеры (413), измеряемая величина упражнения и UUID попыток (400)
def check_session_body(data: SessionIn) -> list[AttemptIn]:
    if len(data.attempts) > MAX_ATTEMPTS:
        raise too_large(f"A session has at most {MAX_ATTEMPTS} attempts")
    expected = measure_meta(data.exercise)
    unique: dict[str, AttemptIn] = {}
    for attempt in data.attempts:
        attempt.analysis_id = normalize_id(attempt.analysis_id, "analysis_id")
        if attempt.measure is not None:
            if len(attempt.measure.series.values) > MAX_VALUES:
                raise too_large(f"A series has at most {MAX_VALUES} values")
            if (attempt.measure.name, attempt.measure.unit) != (expected["name"], expected["unit"]):
                raise AppError("invalid_request", 400, f"measure must be {expected['name']} in {expected['unit']} for {data.exercise}")
        unique.setdefault(attempt.analysis_id, attempt)
    return list(unique.values())


# attempt_to_out — попытка из базы в форме ответа
def attempt_to_out(row: AttemptRow) -> AttemptOut:
    return AttemptOut(
        analysis_id=row.analysis_id, at=row.at, source=row.source, model_version=row.model_version,
        verdict=row.verdict, label=row.label, confidence=row.confidence, measure=row.measure,
    )


# session_to_out — занятие из базы со всеми попытками по времени
def session_to_out(db: Session, row: SessionRow) -> SessionOut:
    attempts = db.scalars(select(AttemptRow).where(AttemptRow.session_id == row.id).order_by(AttemptRow.at, AttemptRow.analysis_id)).all()
    return SessionOut(
        id=row.id, exercise=row.exercise, started_at=row.started_at, created_at=row.created_at,
        attempts=[attempt_to_out(a) for a in attempts],
    )


# check_quota — на аккаунт не больше MAX_USER_SESSIONS занятий и MAX_USER_ATTEMPTS попыток; считаются только новые записи этого запроса
def check_quota(db: Session, user: User, new_sessions: int, new_attempts: int) -> None:
    if new_sessions and db.scalar(select(func.count()).select_from(SessionRow).where(SessionRow.user_id == user.id)) + new_sessions > MAX_USER_SESSIONS:
        raise AppError("quota_exceeded", 413, f"An account can keep at most {MAX_USER_SESSIONS} sessions, delete old ones first")
    if new_attempts and db.scalar(select(func.count()).select_from(AttemptRow).where(AttemptRow.user_id == user.id)) + new_attempts > MAX_USER_ATTEMPTS:
        raise AppError("quota_exceeded", 413, f"An account can keep at most {MAX_USER_ATTEMPTS} attempts, delete old sessions first")


# store_session — одна транзакция: создаёт занятие или дополняет его новыми попытками, сохранённые попытки не меняет, квота тратится только на новое
def store_session(db: Session, user: User, session_id: str, data: SessionIn) -> SessionRow:
    attempts = check_session_body(data)
    data.started_at = data.started_at.astimezone(timezone.utc)
    for attempt in attempts:
        attempt.at = attempt.at.astimezone(timezone.utc)
    row = db.get(SessionRow, session_id)
    if row is not None:
        if row.user_id != user.id:
            raise AppError("id_conflict", 409, "This identifier is already used")
        if row.exercise != data.exercise:
            raise AppError("invalid_request", 400, "The exercise of an existing session cannot change")
    fresh = []
    for attempt in attempts:
        saved = db.get(AttemptRow, attempt.analysis_id)
        if saved is None:
            fresh.append(attempt)
        elif saved.user_id != user.id or saved.session_id != session_id:
            raise AppError("id_conflict", 409, "This identifier is already used")
    check_quota(db, user, 1 if row is None else 0, len(fresh))
    if row is None:
        row = SessionRow(id=session_id, user_id=user.id, exercise=data.exercise, started_at=data.started_at, created_at=utc_now().replace(microsecond=0))
        db.add(row)
        db.flush()
    for attempt in fresh:
        db.add(
            AttemptRow(
                analysis_id=attempt.analysis_id, user_id=user.id, session_id=session_id, at=attempt.at, source=attempt.source,
                model_version=attempt.model_version, verdict=attempt.verdict, label=attempt.label, confidence=attempt.confidence,
                measure_value=attempt.measure.value if attempt.measure else None,
                measure=attempt.measure.model_dump() if attempt.measure else None,
            )
        )
    return row


# save_session — сохраняет занятие; при гонке двух одинаковых запросов повторяет один раз
def save_session(db: Session, user: User, session_id: str, data: SessionIn) -> SessionOut:
    for attempt_number in (1, 2):
        try:
            row = store_session(db, user, session_id, data)
            db.commit()
            return session_to_out(db, row)
        except IntegrityError as exc:
            db.rollback()
            if attempt_number == 2:
                raise AppError("id_conflict", 409, "This identifier is already used") from exc
        except Exception:
            db.rollback()
            raise
    raise AssertionError("unreachable")


# encode_cursor — непрозрачный курсор страницы из времени начала и id последнего занятия
def encode_cursor(row: SessionRow) -> str:
    raw = f"{row.started_at.isoformat()}|{row.id}"
    return base64.urlsafe_b64encode(raw.encode()).decode().rstrip("=")


# decode_cursor — разбирает курсор или отвечает invalid_request
def decode_cursor(cursor: str) -> tuple[datetime, str]:
    try:
        raw = base64.urlsafe_b64decode(cursor + "=" * (-len(cursor) % 4)).decode()
        started, session_id = raw.split("|", 1)
        return datetime.fromisoformat(started).astimezone(timezone.utc), session_id
    except Exception as exc:
        raise AppError("invalid_request", 400, "The cursor is not valid") from exc


# list_sessions — страница занятий, новые первыми, со сводкой по меткам
def list_sessions(db: Session, user: User, exercise: str | None, limit: int, cursor: str | None) -> tuple[list[tuple[SessionRow, dict[str, int]]], str | None]:
    query = select(SessionRow).where(SessionRow.user_id == user.id)
    if exercise:
        query = query.where(SessionRow.exercise == exercise)
    if cursor:
        started, last_id = decode_cursor(cursor)
        query = query.where(or_(SessionRow.started_at < started, and_(SessionRow.started_at == started, SessionRow.id < last_id)))
    rows = list(db.scalars(query.order_by(SessionRow.started_at.desc(), SessionRow.id.desc()).limit(limit + 1)))
    next_cursor = encode_cursor(rows[limit - 1]) if len(rows) > limit else None
    rows = rows[:limit]
    counts: dict[str, dict[str, int]] = {r.id: {label: 0 for label in LABELS} for r in rows}
    if rows:
        grouped = db.execute(
            select(AttemptRow.session_id, AttemptRow.label, func.count()).where(AttemptRow.session_id.in_(counts)).group_by(AttemptRow.session_id, AttemptRow.label)
        )
        for session_id, label, number in grouped:
            counts[session_id][label] = number
    return [(r, counts[r.id]) for r in rows], next_cursor


# get_session — занятие пользователя или 404
def get_session(db: Session, user: User, session_id: str) -> SessionRow:
    row = db.get(SessionRow, session_id)
    if row is None or row.user_id != user.id:
        raise AppError("not_found", 404, "Session not found")
    return row


# delete_session — удаляет занятие и его попытки
def delete_session(db: Session, user: User, session_id: str) -> None:
    db.delete(get_session(db, user, session_id))
    db.commit()


# delete_all_sessions — удаляет всю историю пользователя
def delete_all_sessions(db: Session, user: User) -> None:
    db.execute(delete(SessionRow).where(SessionRow.user_id == user.id))
    db.commit()


# progress_summary — сводка из сохранённых попыток: счётчики, доли, активность по дням, ряд значений
def progress_summary(db: Session, user: User, exercise: str | None, utc_offset_minutes: int) -> dict:
    sessions_query = select(func.count()).select_from(SessionRow).where(SessionRow.user_id == user.id)
    attempts_query = select(AttemptRow.at, AttemptRow.label, AttemptRow.session_id, AttemptRow.measure_value).join(SessionRow, SessionRow.id == AttemptRow.session_id).where(AttemptRow.user_id == user.id)
    if exercise:
        sessions_query = sessions_query.where(SessionRow.exercise == exercise)
        attempts_query = attempts_query.where(SessionRow.exercise == exercise)
    rows = list(db.execute(attempts_query.order_by(AttemptRow.at, AttemptRow.analysis_id)))
    labels = {label: sum(1 for r in rows if r.label == label) for label in LABELS}
    total = len(rows)
    offset = timedelta(minutes=utc_offset_minutes)
    first_day = (utc_now() + offset).date() - timedelta(days=ACTIVITY_DAYS - 1)
    days: dict[str, tuple[set[str], int]] = {}
    for r in rows:
        day = (r.at + offset).date()
        if day >= first_day:
            sessions, repetitions = days.setdefault(day.isoformat(), (set(), 0))
            sessions.add(r.session_id)
            days[day.isoformat()] = (sessions, repetitions + 1)
    points = None
    measure = None
    if exercise:
        measure = measure_meta(exercise)
        points = [{"at": r.at, "value": r.measure_value, "label": r.label} for r in rows if r.measure_value is not None][-POINTS_LIMIT:]
    return {
        "exercise": exercise,
        "sessions": db.scalar(sessions_query),
        "repetitions": total,
        "labels": labels,
        "shares": {label: round(labels[label] / total, 4) for label in LABELS} if total else None,
        "activity": [{"date": d, "sessions": len(s), "repetitions": n} for d, (s, n) in sorted(days.items())],
        "measure": measure,
        "points": points,
    }
