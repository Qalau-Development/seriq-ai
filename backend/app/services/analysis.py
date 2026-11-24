import logging
import threading
from pathlib import Path
from typing import Any

from app.core.config import Settings
from app.core.errors import AppError
from app.services.engine import engine_analyze, engine_warmup
from app.services.mock_analysis import run_mock

analysis_lock = threading.Lock()
logger = logging.getLogger("seriq")


# warmup_model — при старте в режиме model загружает модели и проверяет веса, иначе запуск падает
def warmup_model() -> None:
    logger.info("Model loaded: %s", engine_warmup())


# run_model — запускает движок на видео выбранного упражнения
def run_model(path: Path, exercise: str = "E02") -> dict[str, Any]:
    return engine_analyze(path, exercise)


# run_analysis — выполняет один анализ за раз, при занятости отдаёт 503
def run_analysis(path: Path, settings: Settings, mock_scenario: str, exercise: str = "E02") -> dict[str, Any]:
    if not analysis_lock.acquire(blocking=False):
        raise AppError("busy", 503, "Another analysis is running, retry in a few seconds")
    try:
        if settings.mode == "mock":
            return run_mock(mock_scenario, exercise)
        return run_model(path, exercise)
    finally:
        analysis_lock.release()
