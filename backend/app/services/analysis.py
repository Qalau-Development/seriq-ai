import threading
from pathlib import Path
from typing import Any

from app.core.config import Settings
from app.core.errors import AppError
from app.services.mock_analysis import run_mock

analysis_lock = threading.Lock()


# run_model — запускает seriq_engine на видео (режим model)
def run_model(path: Path) -> dict[str, Any]:
    try:
        from seriq_engine.pipeline import analyze_video
    except ImportError as exc:
        raise AppError("internal_error", 500, "Model mode is not available") from exc
    return analyze_video(str(path))


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
