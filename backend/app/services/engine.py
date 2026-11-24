import importlib
from pathlib import Path
from typing import Any

from app.core.errors import AppError
from app.core.exercises import EXERCISES, measure_meta

ENGINE_ERROR_CODES = {"video_unreadable", "video_too_short", "video_too_long", "no_pose_detected"}


# _registry — модуль seriq_engine.exercises, если движок уже умеет несколько упражнений, иначе None
def _registry() -> Any:
    try:
        return importlib.import_module("seriq_engine.exercises")
    except ModuleNotFoundError as exc:
        if exc.name in ("seriq_engine", "seriq_engine.exercises"):
            return None
        raise


# _legacy_pipeline — модуль seriq_engine.pipeline для движка, который знает только E02
def _legacy_pipeline() -> Any:
    try:
        return importlib.import_module("seriq_engine.pipeline")
    except ImportError as exc:
        raise AppError("internal_error", 500, "Model mode is not available") from exc


# unsupported — ошибка 400 для упражнения, у которого нет готовой модели
def unsupported(exercise_id: str) -> AppError:
    return AppError("unsupported_exercise", 400, f"Exercise {exercise_id} is not supported yet")


# engine_catalog — список упражнений движка с признаком ready; без реестра готово только E02
def engine_catalog() -> list[dict[str, Any]]:
    registry = _registry()
    if registry is not None and hasattr(registry, "catalog"):
        return list(registry.catalog())
    return [{"id": e, "ready": e == "E02", "measure": measure_meta(e)} for e in EXERCISES]


# engine_warmup — при старте загружает модели и проверяет веса, ошибка останавливает запуск
def engine_warmup() -> str:
    registry = _registry()
    if registry is not None and hasattr(registry, "warmup"):
        return str(registry.warmup())
    return str(_legacy_pipeline().warmup())


# measure_from_angles — поле measure для E02 из angle_series: максимум угла и тот же ряд
def measure_from_angles(angle_series: dict[str, Any]) -> dict[str, Any]:
    values = angle_series["values"]
    known = [v for v in values if v is not None]
    return {
        **measure_meta("E02"),
        "value": round(max(known), 1) if known else None,
        "series": {"fps": angle_series["fps"], "values": list(values)},
    }


# engine_analyze — анализ видео движком; ошибки движка переводятся в коды API
def engine_analyze(path: Path, exercise_id: str) -> dict[str, Any]:
    registry = _registry()
    try:
        if registry is not None and hasattr(registry, "analyze_video"):
            result = registry.analyze_video(str(path), exercise_id)
        elif exercise_id == "E02":
            result = _legacy_pipeline().analyze_video(str(path))
        else:
            raise unsupported(exercise_id)
    except AppError:
        raise
    except Exception as exc:
        code = getattr(exc, "api_code", None)
        if code == "unsupported_exercise":
            raise unsupported(exercise_id) from exc
        if code in ENGINE_ERROR_CODES:
            raise AppError(code, 422, str(exc) or code) from exc
        raise
    if "measure" not in result and result.get("angle_series"):
        result = {**result, "measure": measure_from_angles(result["angle_series"])}
    return result
