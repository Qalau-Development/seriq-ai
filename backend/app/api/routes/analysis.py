import time
import uuid

from fastapi import APIRouter, File, Form, UploadFile

from app.core.config import get_settings
from app.core.errors import AppError
from app.schemas.analysis import AnalysisResponse, ErrorResponse
from app.services.analysis import run_analysis
from app.services.upload import temp_upload

router = APIRouter()

ERROR_RESPONSES = {code: {"model": ErrorResponse} for code in (400, 413, 415, 422, 500, 503)}


# POST /api/v1/analysis — принимает видео и возвращает результат анализа
@router.post("/analysis", response_model=AnalysisResponse, responses=ERROR_RESPONSES)
def create_analysis(
    video: UploadFile = File(...),
    exercise: str = Form("E02"),
    mock_scenario: str = "complete",
) -> AnalysisResponse:
    started = time.perf_counter()
    settings = get_settings()
    if exercise != "E02":
        raise AppError("unsupported_exercise", 400, "Only exercise E02 is supported")
    with temp_upload(video, settings.max_upload_bytes) as path:
        result = run_analysis(path, settings, mock_scenario)
    return AnalysisResponse(
        status="ok",
        analysis_id=str(uuid.uuid4()),
        source=settings.mode,
        exercise="E02",
        processing_ms=int((time.perf_counter() - started) * 1000),
        **result,
    )
