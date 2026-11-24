from datetime import datetime
from typing import Literal

from pydantic import AwareDatetime, BaseModel, Field

from app.schemas.analysis import Exercise, Label, Verdict


# SeriesIn — ряд измеряемой величины; длину проверяет сервис, чтобы отвечать 413
class SeriesIn(BaseModel):
    fps: float = Field(gt=0)
    values: list[float | None]


# MeasureIn — измеренная величина попытки
class MeasureIn(BaseModel):
    name: str
    unit: str
    value: float | None
    series: SeriesIn


# AttemptIn — одна попытка в теле PUT /sessions/{id}
class AttemptIn(BaseModel):
    analysis_id: str
    at: AwareDatetime
    source: Literal["mock", "model"]
    model_version: str = Field(max_length=64)
    verdict: Verdict
    label: Label
    confidence: float = Field(ge=0, le=1)
    measure: MeasureIn | None = None


# SessionIn — тело PUT /sessions/{id}; число попыток проверяет сервис, чтобы отвечать 413
class SessionIn(BaseModel):
    exercise: Exercise
    started_at: AwareDatetime
    attempts: list[AttemptIn] = Field(min_length=1)


# AttemptOut — сохранённая попытка
class AttemptOut(BaseModel):
    analysis_id: str
    at: datetime
    source: Literal["mock", "model"]
    model_version: str
    verdict: Verdict
    label: Label
    confidence: float
    measure: MeasureIn | None = None


# SessionOut — сохранённое занятие со всеми попытками
class SessionOut(BaseModel):
    id: str
    exercise: Exercise
    started_at: datetime
    created_at: datetime
    attempts: list[AttemptOut]


# LabelCounts — число попыток по меткам
class LabelCounts(BaseModel):
    complete: int
    incomplete: int
    uncertain: int


# SessionSummary — число попыток в занятии и по меткам
class SessionSummary(LabelCounts):
    total: int


# SessionListItem — занятие в списке, без попыток и рядов
class SessionListItem(BaseModel):
    id: str
    exercise: Exercise
    started_at: datetime
    created_at: datetime
    summary: SessionSummary


# SessionList — страница списка занятий
class SessionList(BaseModel):
    items: list[SessionListItem]
    next_cursor: str | None


# LabelShares — доли меток от 0 до 1
class LabelShares(BaseModel):
    complete: float
    incomplete: float
    uncertain: float


# ActivityDay — активность за один день
class ActivityDay(BaseModel):
    date: str
    sessions: int
    repetitions: int


# MeasureInfo — имя и единицы измеряемой величины
class MeasureInfo(BaseModel):
    name: str
    unit: str


# ProgressPoint — одно измеренное значение во времени
class ProgressPoint(BaseModel):
    at: datetime
    value: float
    label: Label


# ProgressSummary — сводка прогресса: счётчики, доли, активность, ряд значений; без оценок выздоровления
class ProgressSummary(BaseModel):
    exercise: Exercise | None
    sessions: int
    repetitions: int
    labels: LabelCounts
    shares: LabelShares | None
    activity: list[ActivityDay]
    measure: MeasureInfo | None
    points: list[ProgressPoint] | None
