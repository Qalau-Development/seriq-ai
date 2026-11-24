import logging
import threading
from pathlib import Path
from typing import Any

from app.core.config import Settings
from app.core.errors import AppError
from app.services.mock_analysis import run_mock

ENGINE_ERROR_CODES = {"video_unreadable", "video_too_short", "video_too_long", "no_pose_detected"}

analysis_lock = threading.Lock()
logger = logging.getLogger("seriq")


# warmup_model — при старте в режиме model загружает модель и проверяет веса, иначе запуск падает
def warmup_model() -> None:
    from seriq_engine.pipeline import warmup

    logger.info("Model loaded: %s", warmup())


# run_model — запускает seriq_engine на видео и переводит его ошибки в коды API
def run_model(path: Path) -> dict[str, Any]:
    try:
        from seriq_engine.pipeline import analyze_video
    except ImportError as exc:
        raise AppError("internal_error", 500, "Model mode is not available") from exc
    try:
        return analyze_video(str(path))
    except Exception as exc:
        code = getattr(exc, "api_code", None)
        if code in ENGINE_ERROR_CODES:
            raise AppError(code, 422, str(exc) or code) from exc
        raise


# run_analysis — выполняет один анализ за раз, при занятости отдаёт 503
def run_analysis(path: Path, settings: Settings, mock_scenario: str) -> dict[str, Any]:
    if not analysis_lock.acquire(blocking=False):
        raise AppError("busy", 503, "Another analysis is running, retry in a few seconds")
    try:
        if settings.mode == "mock":
            return run_mock(mock_scenario)
        return run_model(path)
    finally:
        analysis_lock.release()
