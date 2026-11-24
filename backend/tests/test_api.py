import json
import tempfile
import threading
import time
import uuid
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.schemas.analysis import AnalysisResponse
from app.services.analysis import analysis_lock

MP4 = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64
WEBM = bytes.fromhex("1A45DFA3") + b"\x00" * 64
EXAMPLES = Path(__file__).resolve().parents[2] / "docs" / "api-examples"
SCENARIO_FILES = {
    "complete": "analysis-complete.json",
    "incomplete": "analysis-incomplete.json",
    "uncertain": "analysis-uncertain.json",
    "no_pose": "error-no-pose.json",
}


# client — тестовый клиент в режиме mock с лимитом 1 МБ и временной папкой
@pytest.fixture
def client(monkeypatch, tmp_path):
    monkeypatch.setenv("SERIQ_MODE", "mock")
    monkeypatch.setenv("SERIQ_MAX_UPLOAD_MB", "1")
    monkeypatch.setattr(tempfile, "tempdir", str(tmp_path))
    return TestClient(create_app(), raise_server_exceptions=False)


# post_video — отправляет файл на анализ
def post_video(client, content=MP4, name="rep.mp4", params=None, data=None):
    return client.post("/api/v1/analysis", params=params, data=data, files={"video": (name, content, "video/mp4")})


# assert_error — проверяет единый формат ошибки
def assert_error(response, status, code):
    assert response.status_code == status
    body = response.json()
    assert body["status"] == "error"
    assert body["error"]["code"] == code
    assert body["error"]["message"]


# test_health — health отдаёт статус, режим и версию
def test_health(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "mode": "mock", "version": "0.1.0"}


# test_docs_paths — документация и схема лежат под /api
def test_docs_paths(client):
    assert client.get("/api/docs").status_code == 200
    assert client.get("/api/openapi.json").status_code == 200


# test_mock_scenarios — все сценарии мока содержат поля из api.md
@pytest.mark.parametrize(
    ("scenario", "label", "verdict", "warnings"),
    [
        ("complete", "complete", "completed", []),
        ("incomplete", "incomplete", "check_instructions", []),
        ("uncertain", "uncertain", "check_instructions", ["arm_not_visible"]),
    ],
)
def test_mock_scenarios(client, scenario, label, verdict, warnings):
    response = post_video(client, params={"mock_scenario": scenario})
    assert response.status_code == 200
    body = response.json()
    AnalysisResponse.model_validate(body)
    assert set(body) == {
        "status", "analysis_id", "source", "model_version", "exercise", "verdict",
        "summary", "cycles", "measure", "angle_series", "warnings", "processing_ms", "pose",
    }
    uuid.UUID(body["analysis_id"])
    assert (body["status"], body["source"], body["model_version"], body["exercise"]) == ("ok", "mock", "mock", "E02")
    assert body["verdict"] == verdict
    assert body["warnings"] == warnings
    assert isinstance(body["processing_ms"], int)
    summary = body["summary"]
    assert summary["total"] == 1 and summary[label] == 1
    assert sum(summary[k] for k in ("complete", "incomplete", "uncertain")) == 1
    (cycle,) = body["cycles"]
    assert set(cycle) == {"index", "start_s", "end_s", "label", "confidence", "verdict"}
    assert cycle["index"] == 1 and cycle["label"] == label and cycle["verdict"] == verdict
    assert 0 <= cycle["confidence"] <= 1 and cycle["start_s"] < cycle["end_s"]
    series = body["angle_series"]
    assert series["fps"] == 10 and series["unit"] == "deg"
    assert all(v is None or 0 <= v <= 180 for v in series["values"])
    assert (None in series["values"]) == (scenario == "uncertain")
    measure = body["measure"]
    assert (measure["name"], measure["unit"]) == ("elbow_angle", "deg")
    assert measure["series"] == {"fps": series["fps"], "values": series["values"]}
    assert measure["value"] == max(v for v in series["values"] if v is not None)


# test_mock_pose — pose мока: кадров столько же, сколько значений угла, null в тех же местах, 21 точка, 4 знака
@pytest.mark.parametrize("scenario", ["complete", "incomplete", "uncertain"])
def test_mock_pose(client, scenario):
    body = post_video(client, params={"mock_scenario": scenario}).json()
    pose, values = body["pose"], body["angle_series"]["values"]
    assert pose["fps"] == body["angle_series"]["fps"]
    assert len(pose["frames"]) == len(values)
    assert [f is None for f in pose["frames"]] == [v is None for v in values]
    assert len(pose["elbow"]) == 2
    for i, frame in enumerate(pose["frames"]):
        if frame is None:
            continue
        assert frame["t"] == pytest.approx(i / pose["fps"])
        assert len(frame["hand"]) == 21 and frame["wrist"] == frame["hand"][0]
        for x, y in frame["hand"]:
            assert round(x, 4) == x and round(y, 4) == y and -1 < x < 2 and -1 < y < 2


# test_mock_default_is_complete — без mock_scenario отдаётся complete
def test_mock_default_is_complete(client):
    assert post_video(client).json()["cycles"][0]["label"] == "complete"


# test_mock_is_deterministic — два запроса различаются только id и временем
def test_mock_is_deterministic(client):
    first, second = (post_video(client).json() for _ in range(2))
    assert first["analysis_id"] != second["analysis_id"]
    for body in (first, second):
        body.pop("analysis_id")
        body.pop("processing_ms")
    assert first == second


# test_mock_no_pose — сценарий no_pose даёт 422 no_pose_detected
def test_mock_no_pose(client):
    assert_error(post_video(client, params={"mock_scenario": "no_pose"}), 422, "no_pose_detected")


# test_examples_match_mock — файлы в docs/api-examples совпадают с ответами мока
@pytest.mark.parametrize("scenario", list(SCENARIO_FILES))
def test_examples_match_mock(client, scenario):
    expected = json.loads((EXAMPLES / SCENARIO_FILES[scenario]).read_text())
    actual = post_video(client, params={"mock_scenario": scenario}).json()
    for body in (expected, actual):
        body.pop("analysis_id", None)
        body.pop("processing_ms", None)
    assert actual == expected


# test_uppercase_extension — .MOV с iPhone принимается
def test_uppercase_extension(client):
    assert post_video(client, name="IMG_0001.MOV").status_code == 200


# test_webm_accepted — webm с верной сигнатурой принимается
def test_webm_accepted(client):
    assert post_video(client, content=WEBM, name="rep.webm").status_code == 200


# test_unsupported_extension — .txt даёт 415
def test_unsupported_extension(client):
    assert_error(post_video(client, content=b"hello", name="notes.txt"), 415, "unsupported_format")


# test_wrong_signature — расширение mp4 при чужом содержимом даёт 415
@pytest.mark.parametrize(("content", "name"), [(b"not a video at all", "rep.mp4"), (MP4, "rep.webm"), (WEBM, "rep.mov")])
def test_wrong_signature(client, content, name):
    assert_error(post_video(client, content=content, name=name), 415, "unsupported_format")


# test_empty_file — пустой файл даёт 400 empty_file
def test_empty_file(client):
    assert_error(post_video(client, content=b""), 400, "empty_file")


# test_missing_video — запрос без поля video даёт 400 missing_video
def test_missing_video(client):
    assert_error(client.post("/api/v1/analysis", data={"exercise": "E02"}), 400, "missing_video")


# test_unsupported_exercise — упражнение не E02 даёт 400
def test_unsupported_exercise(client):
    assert_error(post_video(client, data={"exercise": "E05"}), 400, "unsupported_exercise")


# test_exercise_e02_explicit — явный E02 принимается
def test_exercise_e02_explicit(client):
    assert post_video(client, data={"exercise": "E02"}).status_code == 200


# test_file_too_large — файл больше лимита даёт 413
def test_file_too_large(client):
    assert_error(post_video(client, content=MP4 + b"\x00" * (1024 * 1024)), 413, "file_too_large")


# test_busy — пока идёт другой анализ, приходит 503 busy
def test_busy(client, monkeypatch):
    monkeypatch.setattr("app.services.analysis.BUSY_WAIT_S", 0.1)
    assert analysis_lock.acquire(blocking=False)
    try:
        assert_error(post_video(client), 503, "busy")
    finally:
        analysis_lock.release()
    assert post_video(client).status_code == 200


# test_busy_waits_in_queue — занятый запрос ждёт освобождения и получает 200, а не 503; временный файл удаляется
def test_busy_waits_in_queue(client, tmp_path):
    assert analysis_lock.acquire(blocking=False)
    threading.Timer(0.3, analysis_lock.release).start()
    started = time.perf_counter()
    response = post_video(client)
    assert response.status_code == 200
    assert time.perf_counter() - started >= 0.25
    assert list(tmp_path.iterdir()) == []


# test_internal_error — неожиданная ошибка даёт 500 internal_error в едином формате
def test_internal_error(client, monkeypatch):
    # boom — имитирует неожиданное исключение анализа
    def boom(*args, **kwargs):
        raise RuntimeError("secret details")

    monkeypatch.setattr("app.api.routes.analysis.run_analysis", boom)
    response = post_video(client)
    assert_error(response, 500, "internal_error")
    assert "secret" not in response.text


# test_lock_released_after_error — после ошибки анализа блокировка свободна
def test_lock_released_after_error(client):
    post_video(client, params={"mock_scenario": "no_pose"})
    assert post_video(client).status_code == 200


# test_temp_file_removed — временный файл удалён после успеха и после любой ошибки
@pytest.mark.parametrize(
    ("kwargs", "status"),
    [
        ({}, 200),
        ({"params": {"mock_scenario": "no_pose"}}, 422),
        ({"content": b"not a video at all"}, 415),
        ({"content": MP4 + b"\x00" * (1024 * 1024)}, 413),
        ({"content": b""}, 400),
    ],
)
def test_temp_file_removed(client, tmp_path, kwargs, status):
    assert post_video(client, **kwargs).status_code == status
    assert list(tmp_path.iterdir()) == []


# test_temp_file_removed_when_busy — при 503 временный файл тоже удалён
def test_temp_file_removed_when_busy(client, tmp_path, monkeypatch):
    monkeypatch.setattr("app.services.analysis.BUSY_WAIT_S", 0.1)
    assert analysis_lock.acquire(blocking=False)
    try:
        assert post_video(client).status_code == 503
    finally:
        analysis_lock.release()
    assert list(tmp_path.iterdir()) == []


# test_invalid_mode — неизвестный SERIQ_MODE останавливает запуск
def test_invalid_mode(monkeypatch):
    monkeypatch.setenv("SERIQ_MODE", "fake")
    with pytest.raises(ValueError):
        create_app()
