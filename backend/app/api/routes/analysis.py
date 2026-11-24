import time
import uuid

from fastapi import APIRouter, File, Form, UploadFile

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.exercises import EXERCISES
from app.schemas.analysis import AnalysisResponse, ErrorResponse
from app.services.analysis import run_analysis
from app.services.engine import engine_catalog, unsupported
from app.services.upload import temp_upload

router = APIRouter()

ERROR_RESPONSES = {code: {"model": ErrorResponse} for code in (400, 413, 415, 422, 500, 503)}


# check_exercise — до чтения файла: код должен быть E01–E04, а в режиме model движок должен быть готов к нему
def check_exercise(exercise: str, mode: str) -> None:
    if exercise not in EXERCISES:
        raise unsupported(exercise)
    if mode == "model" and not any(e.get("id") == exercise and e.get("ready") for e in engine_catalog()):
        raise unsupported(exercise)


# POST /api/v1/analysis — принимает видео и возвращает результат анализа
@router.post("/analysis", response_model=AnalysisResponse, responses=ERROR_RESPONSES)
def create_analysis(
    video: UploadFile = File(...),
    exercise: str = Form("E02"),
    mock_scenario: str = "complete",
) -> AnalysisResponse:
    started = time.perf_counter()
    settings = get_settings()
    check_exercise(exercise, settings.mode)
    with temp_upload(video, settings.max_upload_bytes) as path:
        result = run_analysis(path, settings, mock_scenario, exercise)
    return AnalysisResponse(
        **{
            **result,
            "status": "ok",
            "analysis_id": str(uuid.uuid4()),
            "source": settings.mode,
            "exercise": exercise,
            "processing_ms": int((time.perf_counter() - started) * 1000),
        }
    )
