import pytest

from seriq_engine import exercises
from seriq_engine.errors import UnsupportedExercise
from seriq_engine.pipeline import analyze_video


# test_catalog_lists_four_exercises — каталог содержит E01–E04 с именами величин из контракта
def test_catalog_lists_four_exercises(monkeypatch):
    monkeypatch.setenv("SERIQ_MODEL_PATH", "/nonexistent/e02_classifier.joblib")
    items = {c["id"]: c for c in exercises.catalog()}
    assert list(items) == ["E01", "E02", "E03", "E04"]
    assert items["E01"]["measure"] == {"name": "lift_height", "unit": "hand_lengths"}
    assert items["E02"]["measure"] == {"name": "elbow_angle", "unit": "deg"}
    assert items["E03"]["measure"] == {"name": "wrist_lift", "unit": "deg"}
    assert items["E04"]["measure"] == {"name": "hand_openness", "unit": "percent"}
    assert not any(c["ready"] for c in items.values())


# test_e02_ready_with_model — E02 готово, когда файл модели на месте
def test_e02_ready_with_model(monkeypatch, tmp_path):
    (tmp_path / "e02_classifier.joblib").write_bytes(b"x")
    monkeypatch.setenv("SERIQ_MODEL_PATH", str(tmp_path / "e02_classifier.joblib"))
    ready = {c["id"]: c["ready"] for c in exercises.catalog()}
    assert ready["E02"] and not ready["E01"]


# test_exercise_without_model_not_ready — у упражнения есть модуль, но нет модели: не готово
def test_exercise_without_model_not_ready(monkeypatch, tmp_path):
    monkeypatch.setenv("SERIQ_MODEL_PATH", str(tmp_path / "e02_classifier.joblib"))
    assert not exercises.is_ready("E02")


# test_unknown_exercise — неизвестное и неготовое упражнение дают UnsupportedExercise с кодом API
@pytest.mark.parametrize("exercise", ["E05", "E99", "", "e02"])
def test_unknown_exercise(exercise, tmp_path, monkeypatch):
    monkeypatch.setenv("SERIQ_MODEL_PATH", "/nonexistent/e02_classifier.joblib")
    with pytest.raises(UnsupportedExercise) as err:
        analyze_video(tmp_path / "none.mp4", exercise)
    assert err.value.api_code == "unsupported_exercise"


# test_model_file_next_to_e02 — модели других упражнений лежат рядом с моделью E02
def test_model_file_next_to_e02(monkeypatch):
    monkeypatch.setenv("SERIQ_MODEL_PATH", "/srv/models/e02_classifier.joblib")
    assert str(exercises.model_file("E04")) == "/srv/models/e04_classifier.joblib"
    assert str(exercises.model_file("E02")) == "/srv/models/e02_classifier.joblib"


# test_no_hand_gives_no_pose — видео без кисти у E04 даёт ArmNotFound (422 no_pose_detected), а не падение
def test_no_hand_gives_no_pose(monkeypatch, tmp_path):
    import cv2
    import numpy as np
    from pathlib import Path

    root = Path(__file__).resolve().parents[2]
    hand = root / "data" / "processed" / "mp_models" / "hand_landmarker.task"
    if not hand.is_file() or not (root / "models" / "e04_classifier.joblib").is_file():
        pytest.skip("local weights or E04 model not available")
    monkeypatch.setenv("SERIQ_HAND_MODEL_PATH", str(hand))
    monkeypatch.setenv("SERIQ_MODEL_PATH", str(root / "models" / "e02_classifier.joblib"))
    video = tmp_path / "empty.mp4"
    writer = cv2.VideoWriter(str(video), cv2.VideoWriter_fourcc(*"mp4v"), 10, (64, 48))
    for _ in range(30):
        writer.write(np.full((48, 64, 3), 128, np.uint8))
    writer.release()
    from seriq_engine.errors import ArmNotFound

    for exercise in ("E02", "E03", "E04"):
        with pytest.raises(ArmNotFound) as err:
            analyze_video(video, exercise)
        assert err.value.api_code == "no_pose_detected"


# test_hand_recovery_off_by_default — второй проход поиска кисти выключен у всех упражнений, пока команда его не включит
@pytest.mark.parametrize("exercise", ["E01", "E02", "E03", "E04"])
def test_hand_recovery_off_by_default(exercise):
    import importlib

    module = importlib.import_module(f"seriq_engine.exercises.{exercise.lower()}")
    assert getattr(module, "RECOVER_HAND", False) is False
