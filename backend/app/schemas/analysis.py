from typing import Literal

from pydantic import BaseModel, Field

Label = Literal["complete", "incomplete", "uncertain"]
Verdict = Literal["completed", "check_instructions"]
Exercise = Literal["E01", "E02", "E03", "E04"]


# HealthResponse — ответ проверки сервера
class HealthResponse(BaseModel):
    status: Literal["ok"]
    mode: Literal["mock", "model"]
    version: str
    database: Literal["ok", "unavailable"] | None = None


# Summary — число циклов по меткам
class Summary(BaseModel):
    total: int
    complete: int
    incomplete: int
    uncertain: int


# Cycle — решение по одному циклу
class Cycle(BaseModel):
    index: int
    start_s: float
    end_s: float
    label: Label
    confidence: float
    verdict: Verdict


# AngleSeries — угол локтя по кадрам для графика
class AngleSeries(BaseModel):
    fps: float
    unit: Literal["deg"]
    values: list[float | None]


# MeasureSeries — значения измеряемой величины по кадрам для графика
class MeasureSeries(BaseModel):
    fps: float
    values: list[float | None]


# Measure — главная измеряемая величина упражнения: имя, единицы, итог и ряд по кадрам
class Measure(BaseModel):
    name: str
    unit: str
    value: float | None
    series: MeasureSeries


Point = tuple[float, float]


# PoseFrame — точки кисти в одном кадре, в долях ширины и высоты кадра
class PoseFrame(BaseModel):
    t: float
    wrist: Point
    hand: list[Point] = Field(min_length=21, max_length=21)


# Pose — необязательное поле: точки кисти по кадрам для линии руки на видео, локоть только у E02
class Pose(BaseModel):
    fps: float
    elbow: Point | None = None
    frames: list[PoseFrame | None]


# AnalysisResponse — успешный ответ анализа по api.md
class AnalysisResponse(BaseModel):
    status: Literal["ok"]
    analysis_id: str
    source: Literal["mock", "model"]
    model_version: str
    exercise: Exercise
    verdict: Verdict
    summary: Summary
    cycles: list[Cycle]
    measure: Measure
    angle_series: AngleSeries | None = None
    warnings: list[Literal["arm_not_visible"]]
    processing_ms: int
    pose: Pose | None = None


# ExerciseMeasure — имя и единицы измерения упражнения в каталоге
class ExerciseMeasure(BaseModel):
    name: str
    unit: str


# ExerciseItem — упражнение каталога: код, готовность модели и что измеряется
class ExerciseItem(BaseModel):
    id: Exercise
    measure: ExerciseMeasure
    ready: bool


# ErrorBody — код и сообщение ошибки
class ErrorBody(BaseModel):
    code: str
    message: str


# ErrorResponse — единый формат ошибки
class ErrorResponse(BaseModel):
    status: Literal["error"]
    error: ErrorBody
