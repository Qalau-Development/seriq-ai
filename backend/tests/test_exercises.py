import sys
import tempfile
import types
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.schemas.analysis import AnalysisResponse, ExerciseItem
from tests.test_model_mode import RESULT as E02_RESULT
from tests.test_model_mode import EngineFailure

MP4 = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64
MEASURES = {
    "E01": ("lift_height", "hand_lengths"),
    "E02": ("elbow_angle", "deg"),
    "E03": ("wrist_lift", "deg"),
    "E04": ("hand_openness", "percent"),
}
PEAKS = {
    "E01": {"complete": 2.5, "incomplete": 0.6, "uncertain": 1.4},
    "E03": {"complete": 35.0, "incomplete": 10.0, "uncertain": 20.0},
    "E04": {"complete": 95.0, "incomplete": 50.0, "uncertain": 70.0},
}
HAND_FRAME = {"t": 0.0, "wrist": [0.2, 0.4], "hand": [[0.2, 0.4]] * 21}
OTHER_RESULT = {
    "model_version": "e04-test-1",
    "verdict": "completed",
    "summary": {"total": 1, "complete": 1, "incomplete": 0, "uncertain": 0},
    "cycles": [{"index": 1, "start_s": 0.0, "end_s": 5.0, "label": "complete", "confidence": 0.9, "verdict": "completed"}],
    "measure": {"name": "hand_openness", "unit": "percent", "value": 92.0, "series": {"fps": 10.0, "values": [20.0, None, 92.0]}},
    "angle_series": None,
    "pose": {"fps": 10.0, "frames": [HAND_FRAME, None, HAND_FRAME]},
    "warnings": [],
}


# post_video — отправляет файл на анализ выбранного упражнения
def post_video(client, exercise=None, params=None):
    return client.post(
        "/api/v1/analysis",
        params=params,
        data={"exercise": exercise} if exercise else None,
        files={"video": ("rep.mp4", MP4, "video/mp4")},
    )


# mode_client — клиент в заданном режиме с временной папкой
def mode_client(monkeypatch, tmp_path, mode):
    monkeypatch.setenv("SERIQ_MODE", mode)
    monkeypatch.setattr(tempfile, "tempdir", str(tmp_path))
    return TestClient(create_app(), raise_server_exceptions=False)


# mock_client — клиент в режиме mock
@pytest.fixture
def mock_client(monkeypatch, tmp_path):
    return mode_client(monkeypatch, tmp_path, "mock")


# install_engine — подменяет seriq_engine: со старым pipeline и, если задан catalog, с новым exercises
def install_engine(monkeypatch, catalog=None, analyze=None):
    package = types.ModuleType("seriq_engine")
    pipeline = types.ModuleType("seriq_engine.pipeline")
    pipeline.warmup = lambda: "e02-test-1"
    pipeline.analyze_video = lambda path: E02_RESULT
    package.pipeline = pipeline
    monkeypatch.setitem(sys.modules, "seriq_engine", package)
    monkeypatch.setitem(sys.modules, "seriq_engine.pipeline", pipeline)
    if catalog is None:
        return None
    registry = types.ModuleType("seriq_engine.exercises")
    registry.calls = []
    registry.catalog = lambda: catalog
    registry.warmup = lambda: "multi-test-1"

    # analyze_video — запоминает путь и упражнение и отдаёт заданный ответ
    def analyze_video(path, exercise):
        registry.calls.append((Path(path).exists(), exercise))
        return analyze(exercise) if analyze else OTHER_RESULT

    registry.analyze_video = analyze_video
    package.exercises = registry
    monkeypatch.setitem(sys.modules, "seriq_engine.exercises", registry)
    return registry


# catalog_item — запись каталога движка
def catalog_item(exercise, ready):
    name, unit = MEASURES[exercise]
    return {"id": exercise, "ready": ready, "measure": {"name": name, "unit": unit}}


# test_mock_e02_explicit_has_measure — E02 в моке даёт measure из angle_series
def test_mock_e02_explicit_has_measure(mock_client):
    body = post_video(mock_client, "E02").json()
    assert body["measure"]["series"]["values"] == body["angle_series"]["values"]
    assert body["pose"]["elbow"] is not None


# test_mock_other_exercises — E01/E03/E04 в моке: свои имя и единицы, без angle_series и локтя
@pytest.mark.parametrize("exercise", ["E01", "E03", "E04"])
@pytest.mark.parametrize("scenario", ["complete", "incomplete", "uncertain"])
def test_mock_other_exercises(mock_client, exercise, scenario):
    response = post_video(mock_client, exercise, {"mock_scenario": scenario})
    assert response.status_code == 200
    body = response.json()
    AnalysisResponse.model_validate(body)
    assert body["exercise"] == exercise and body["source"] == "mock" and body["model_version"] == "mock"
    measure = body["measure"]
    assert (measure["name"], measure["unit"]) == MEASURES[exercise]
    values = measure["series"]["values"]
    assert measure["series"]["fps"] == 10 and len(values) == 100
    assert (None in values) == (scenario == "uncertain")
    assert measure["value"] == max(v for v in values if v is not None)
    assert measure["value"] == pytest.approx(PEAKS[exercise][scenario], rel=0.05)
    pose = body["pose"]
    assert "elbow" not in pose and "angle_series" not in body
    assert [f is None for f in pose["frames"]] == [v is None for v in values]
    for frame in pose["frames"]:
        assert frame is None or (len(frame["hand"]) == 21 and frame["wrist"] == frame["hand"][0])


# test_e04_json_has_no_elbow_and_angle_series — у E04 в JSON нет ключей elbow и angle_series, а measure.value может быть null
@pytest.mark.parametrize("mode", ["mock", "model"])
def test_e04_json_has_no_elbow_and_angle_series(monkeypatch, tmp_path, mode):
    install_engine(monkeypatch, [catalog_item("E04", True)])
    client = mode_client(monkeypatch, tmp_path, mode)
    body = post_video(client, "E04").json()
    assert "angle_series" not in body and "elbow" not in body["pose"]


# test_e02_json_keeps_angle_series_and_elbow — у E02 в JSON остаются angle_series и elbow
def test_e02_json_keeps_angle_series_and_elbow(mock_client):
    body = post_video(mock_client, "E02").json()
    assert body["angle_series"] is not None and body["pose"]["elbow"] is not None


# test_measure_value_null_kept — measure.value = null остаётся в ответе
def test_measure_value_null_kept(monkeypatch, tmp_path):
    empty = {**OTHER_RESULT, "measure": {**OTHER_RESULT["measure"], "value": None}}
    install_engine(monkeypatch, [catalog_item("E04", True)], lambda exercise: empty)
    body = post_video(mode_client(monkeypatch, tmp_path, "model"), "E04").json()
    assert "value" in body["measure"] and body["measure"]["value"] is None


# test_mock_other_exercises_deterministic — повторный запрос даёт то же самое
def test_mock_other_exercises_deterministic(mock_client):
    first, second = (post_video(mock_client, "E04").json() for _ in range(2))
    for body in (first, second):
        body.pop("analysis_id")
        body.pop("processing_ms")
    assert first == second


# test_mock_other_exercises_verdicts — вердикт и метки те же, что у E02
@pytest.mark.parametrize("exercise", ["E01", "E03", "E04"])
def test_mock_other_exercises_verdicts(mock_client, exercise):
    for scenario, verdict in (("complete", "completed"), ("incomplete", "check_instructions"), ("uncertain", "check_instructions")):
        body = post_video(mock_client, exercise, {"mock_scenario": scenario}).json()
        assert body["verdict"] == verdict and body["cycles"][0]["label"] == scenario
    assert post_video(mock_client, exercise, {"mock_scenario": "no_pose"}).json()["error"]["code"] == "no_pose_detected"


# test_unknown_exercise — неизвестный код даёт 400 unsupported_exercise и в моке, и в model
@pytest.mark.parametrize("mode", ["mock", "model"])
@pytest.mark.parametrize("code", ["E05", "e02", "E2", "E02 "])
def test_unknown_exercise(monkeypatch, tmp_path, mode, code):
    install_engine(monkeypatch)
    client = mode_client(monkeypatch, tmp_path, mode)
    response = post_video(client, code)
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "unsupported_exercise"


# test_unknown_exercise_before_file — код проверяется до чтения файла: плохой файл не даёт 415
def test_unknown_exercise_before_file(mock_client):
    response = mock_client.post("/api/v1/analysis", data={"exercise": "E05"}, files={"video": ("x.txt", b"hello", "text/plain")})
    assert response.status_code == 400 and response.json()["error"]["code"] == "unsupported_exercise"


# test_catalog_mock — каталог в моке: все четыре готовы, у каждого measure
def test_catalog_mock(mock_client):
    response = mock_client.get("/api/v1/exercises")
    assert response.status_code == 200
    body = response.json()
    assert isinstance(body, list)
    for item in body:
        ExerciseItem.model_validate(item)
        assert set(item) == {"id", "measure", "ready"}
    assert [e["id"] for e in body] == ["E01", "E02", "E03", "E04"]
    assert all(e["ready"] for e in body)
    assert {e["id"]: (e["measure"]["name"], e["measure"]["unit"]) for e in body} == MEASURES


# test_catalog_model_legacy — со старым движком готово только E02
def test_catalog_model_legacy(monkeypatch, tmp_path):
    install_engine(monkeypatch)
    body = mode_client(monkeypatch, tmp_path, "model").get("/api/v1/exercises").json()
    assert {e["id"]: e["ready"] for e in body} == {"E01": False, "E02": True, "E03": False, "E04": False}


# test_catalog_model_registry — в model каталог берётся у движка как есть
def test_catalog_model_registry(monkeypatch, tmp_path):
    catalog = [catalog_item("E02", True), catalog_item("E04", False)]
    install_engine(monkeypatch, catalog)
    body = mode_client(monkeypatch, tmp_path, "model").get("/api/v1/exercises").json()
    assert body == catalog


# test_model_legacy_engine — старый движок: E02 работает и получает measure, E04 даёт 400 до чтения файла
def test_model_legacy_engine(monkeypatch, tmp_path):
    install_engine(monkeypatch)
    client = mode_client(monkeypatch, tmp_path, "model")
    body = post_video(client, "E02").json()
    AnalysisResponse.model_validate(body)
    assert body["exercise"] == "E02" and body["measure"] == {
        "name": "elbow_angle", "unit": "deg", "value": 120.5, "series": {"fps": 10.0, "values": [95.0, None, 120.5]},
    }
    assert body["angle_series"] == E02_RESULT["angle_series"] and body["pose"] == E02_RESULT["pose"]
    response = post_video(client, "E04")
    assert response.status_code == 400 and response.json()["error"]["code"] == "unsupported_exercise"
    assert list(tmp_path.iterdir()) == []


# test_model_registry_passes_exercise — новый движок получает упражнение, ответ идёт по контракту
def test_model_registry_passes_exercise(monkeypatch, tmp_path):
    registry = install_engine(monkeypatch, [catalog_item(e, True) for e in MEASURES])
    client = mode_client(monkeypatch, tmp_path, "model")
    body = post_video(client, "E04").json()
    AnalysisResponse.model_validate(body)
    assert registry.calls == [(True, "E04")]
    assert body["exercise"] == "E04" and body["source"] == "model" and body["model_version"] == "e04-test-1"
    assert body["measure"]["value"] == 92.0 and body["pose"]["frames"][1] is None
    assert "angle_series" not in body and "elbow" not in body["pose"]
    assert list(tmp_path.iterdir()) == []


# test_model_registry_keeps_engine_measure — измерение E02 от нового движка не пересчитывается
def test_model_registry_keeps_engine_measure(monkeypatch, tmp_path):
    measure = {"name": "elbow_angle", "unit": "deg", "value": 100.0, "series": {"fps": 10.0, "values": [100.0]}}
    registry = install_engine(monkeypatch, [catalog_item("E02", True)], lambda exercise: {**E02_RESULT, "measure": measure})
    body = post_video(mode_client(monkeypatch, tmp_path, "model")).json()
    assert registry.calls == [(True, "E02")] and body["measure"] == measure


# test_model_registry_not_ready — неготовое упражнение даёт 400 и движок не вызывается
def test_model_registry_not_ready(monkeypatch, tmp_path):
    registry = install_engine(monkeypatch, [catalog_item("E02", True), catalog_item("E03", False)])
    client = mode_client(monkeypatch, tmp_path, "model")
    for exercise in ("E03", "E01"):
        response = post_video(client, exercise)
        assert response.status_code == 400 and response.json()["error"]["code"] == "unsupported_exercise"
    assert registry.calls == [] and list(tmp_path.iterdir()) == []


# test_model_registry_engine_unsupported — движок сам отказал по api_code unsupported_exercise: 400
def test_model_registry_engine_unsupported(monkeypatch, tmp_path):
    def refuse(exercise):
        raise EngineFailure("unsupported_exercise")

    install_engine(monkeypatch, [catalog_item("E04", True)], refuse)
    response = post_video(mode_client(monkeypatch, tmp_path, "model"), "E04")
    assert response.status_code == 400 and response.json()["error"]["code"] == "unsupported_exercise"


# test_model_registry_errors — ошибки нового движка: 422 с кодом, прочие 500 без подробностей
@pytest.mark.parametrize("code", ["video_unreadable", "video_too_short", "video_too_long", "no_pose_detected"])
def test_model_registry_errors(monkeypatch, tmp_path, code):
    def fail(exercise):
        raise EngineFailure(code)

    install_engine(monkeypatch, [catalog_item("E04", True)], fail)
    response = post_video(mode_client(monkeypatch, tmp_path, "model"), "E04")
    assert response.status_code == 422 and response.json()["error"]["code"] == code
    assert list(tmp_path.iterdir()) == []


# test_model_registry_unexpected_error — неожиданная ошибка нового движка даёт 500 internal_error
def test_model_registry_unexpected_error(monkeypatch, tmp_path):
    def boom(exercise):
        raise RuntimeError("secret details")

    install_engine(monkeypatch, [catalog_item("E04", True)], boom)
    response = post_video(mode_client(monkeypatch, tmp_path, "model"), "E04")
    assert response.status_code == 500 and "secret" not in response.text


# test_model_registry_warmup — при старте вызывается warmup нового движка
def test_model_registry_warmup(monkeypatch, tmp_path):
    registry = install_engine(monkeypatch, [catalog_item("E02", True)])
    seen = []
    registry.warmup = lambda: seen.append(1) or "multi-test-1"
    mode_client(monkeypatch, tmp_path, "model")
    assert seen == [1]
