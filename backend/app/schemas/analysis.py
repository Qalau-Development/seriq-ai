from typing import Literal

from pydantic import BaseModel

Label = Literal["complete", "incomplete", "uncertain"]
Verdict = Literal["completed", "check_instructions"]


# HealthResponse — ответ проверки сервера
class HealthResponse(BaseModel):
    status: Literal["ok"]
    mode: Literal["mock", "model"]
    version: str


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


# AnalysisResponse — успешный ответ анализа по api.md
class AnalysisResponse(BaseModel):
    status: Literal["ok"]
    analysis_id: str
    source: Literal["mock", "model"]
    model_version: str
    exercise: Literal["E02"]
    verdict: Verdict
    summary: Summary
    cycles: list[Cycle]
    angle_series: AngleSeries
    warnings: list[Literal["arm_not_visible"]]
    processing_ms: int


# ErrorBody — код и сообщение ошибки
class ErrorBody(BaseModel):
    code: str
    message: str


# ErrorResponse — единый формат ошибки
class ErrorResponse(BaseModel):
    status: Literal["error"]
    error: ErrorBody
