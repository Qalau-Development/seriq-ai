import sys
import tempfile
import types
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.main import create_app
from app.schemas.analysis import AnalysisResponse

MP4 = b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 64
RESULT = {
    "model_version": "e02-test-1",
    "verdict": "check_instructions",
    "summary": {"total": 1, "complete": 0, "incomplete": 1, "uncertain": 0},
    "cycles": [{"index": 1, "start_s": 0.0, "end_s": 9.5, "label": "incomplete", "confidence": 0.93, "verdict": "check_instructions"}],
    "angle_series": {"fps": 10.0, "unit": "deg", "values": [95.0, None, 120.5]},
    "warnings": [],
}


# EngineFailure — ошибка движка с кодом api_code, как в seriq_engine.errors
class EngineFailure(Exception):
    # __init__ — сохраняет код ошибки API
    def __init__(self, code: str) -> None:
        super().__init__(f"engine failed: {code}")
        self.api_code = code


# engine — поддельный seriq_engine.pipeline: бэкенд тестируется без MediaPipe и модели
@pytest.fixture
def engine(monkeypatch):
    module = types.ModuleType("seriq_engine.pipeline")
    module.seen_paths = []
    module.raise_error = None

    # analyze_video — запоминает путь и отдаёт RESULT или выбрасывает заданную ошибку
    def analyze_video(path):
        module.seen_paths.append((path, Path(path).exists()))
        if module.raise_error:
            raise module.raise_error
        return RESULT

    module.analyze_video = analyze_video
    module.warmup = lambda: "e02-test-1"
    package = types.ModuleType("seriq_engine")
    package.pipeline = module
    monkeypatch.setitem(sys.modules, "seriq_engine", package)
    monkeypatch.setitem(sys.modules, "seriq_engine.pipeline", module)
    return module


# client — клиент в режиме model с временной папкой
@pytest.fixture
def client(engine, monkeypatch, tmp_path):
    monkeypatch.setenv("SERIQ_MODE", "model")
    monkeypatch.setattr(tempfile, "tempdir", str(tmp_path))
    return TestClient(create_app(), raise_server_exceptions=False)


# post_video — отправляет файл на анализ
def post_video(client, params=None):
    return client.post("/api/v1/analysis", params=params, files={"video": ("rep.mp4", MP4, "video/mp4")})


# test_health_model_mode — health показывает режим model
def test_health_model_mode(client):
    assert client.get("/api/v1/health").json()["mode"] == "model"


# test_model_result — ответ движка отдаётся по контракту с source model
def test_model_result(client, engine, tmp_path):
    response = post_video(client, params={"mock_scenario": "complete"})
    assert response.status_code == 200
    body = response.json()
    AnalysisResponse.model_validate(body)
    assert body["source"] == "model" and body["model_version"] == "e02-test-1"
    assert body["cycles"][0]["label"] == "incomplete"
    ((path, existed),) = engine.seen_paths
    assert existed and not Path(path).exists()
    assert list(tmp_path.iterdir()) == []


# test_engine_errors — ошибки движка становятся 422 с кодом из api.md
@pytest.mark.parametrize("code", ["video_unreadable", "video_too_short", "video_too_long", "no_pose_detected"])
def test_engine_errors(client, engine, tmp_path, code):
    engine.raise_error = EngineFailure(code)
    response = post_video(client)
    assert response.status_code == 422
    assert response.json() == {"status": "error", "error": {"code": code, "message": f"engine failed: {code}"}}
    assert list(tmp_path.iterdir()) == []


# test_unexpected_engine_error — прочие ошибки движка дают 500 internal_error без подробностей
def test_unexpected_engine_error(client, engine):
    engine.raise_error = RuntimeError("secret details")
    response = post_video(client)
    assert response.status_code == 500
    assert response.json()["error"]["code"] == "internal_error" and "secret" not in response.text


# test_warmup_failure_stops_start — без модели или весов приложение не запускается
def test_warmup_failure_stops_start(engine, monkeypatch):
    monkeypatch.setenv("SERIQ_MODE", "model")

    # broken_warmup — имитирует отсутствие файла модели
    def broken_warmup():
        raise FileNotFoundError("model not found")

    engine.warmup = broken_warmup
    with pytest.raises(FileNotFoundError):
        create_app()
