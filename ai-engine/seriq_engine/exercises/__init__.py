import importlib
import importlib.util
from pathlib import Path
from types import ModuleType

from seriq_engine.classifier import model_path
from seriq_engine.errors import UnsupportedExercise

MEASURES = {
    "E01": {"name": "lift_height", "unit": "hand_lengths"},
    "E02": {"name": "elbow_angle", "unit": "deg"},
    "E03": {"name": "wrist_lift", "unit": "deg"},
    "E04": {"name": "hand_openness", "unit": "percent"},
}


# model_file — файл модели упражнения: у E02 путь из SERIQ_MODEL_PATH, у остальных рядом с ним
def model_file(exercise: str) -> Path:
    if exercise == "E02":
        return Path(model_path())
    return Path(model_path()).with_name(f"{exercise.lower()}_classifier.joblib")


# is_ready — у упражнения есть модуль и файл модели
def is_ready(exercise: str) -> bool:
    has_module = importlib.util.find_spec(f"seriq_engine.exercises.{exercise.lower()}") is not None
    return has_module and model_file(exercise).is_file()


# get_module — модуль упражнения; неизвестное или неготовое упражнение даёт UnsupportedExercise
def get_module(exercise: str, check_model: bool = True) -> ModuleType:
    has_module = exercise in MEASURES and importlib.util.find_spec(f"seriq_engine.exercises.{exercise.lower()}") is not None
    if not has_module or (check_model and not model_file(exercise).is_file()):
        raise UnsupportedExercise(f"Exercise {exercise} is not supported")
    return importlib.import_module(f"seriq_engine.exercises.{exercise.lower()}")


# catalog — все упражнения с признаком готовности и измеряемой величиной
def catalog() -> list[dict]:
    return [{"id": e, "ready": is_ready(e), "measure": dict(m)} for e, m in MEASURES.items()]


# analyze_video — анализирует видео выбранного упражнения и возвращает результат по docs/api.md
def analyze_video(path: str | Path, exercise: str = "E02") -> dict:
    from seriq_engine.pipeline import analyze_video as run

    return run(path, exercise)


# warmup — загружает модели всех готовых упражнений и создаёт HandLandmarker
def warmup() -> str:
    from seriq_engine.pipeline import warmup as run

    return run()
