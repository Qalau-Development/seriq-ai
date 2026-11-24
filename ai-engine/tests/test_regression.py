import hashlib
import json
from pathlib import Path

import pytest

from seriq_engine.exercises import analyze_video

ROOT = Path(__file__).resolve().parents[2]
EXERCISE_DIR = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise"
HAND = ROOT / "data/processed/mp_models/hand_landmarker.task"
ANSWERS = json.loads((Path(__file__).parent / "data/regression_answers.json").read_text())


# field_hash — sha256 поля ответа в каноническом JSON, как в ml-training/make_regression.py
def field_hash(value) -> str:
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


# test_answer_unchanged — ответ на train-видео совпадает с эталоном побайтово по всем прежним полям; новые поля допускаются
@pytest.mark.parametrize("case", ANSWERS, ids=[f"{a['exercise']}-{Path(a['video']).name}" for a in ANSWERS])
def test_answer_unchanged(case, monkeypatch):
    video = EXERCISE_DIR / case["video"]
    if not video.is_file() or not HAND.is_file():
        pytest.skip("local dataset or hand landmarker weights not available")
    monkeypatch.setenv("SERIQ_MODEL_PATH", str(ROOT / "models/e02_classifier.joblib"))
    monkeypatch.setenv("SERIQ_HAND_MODEL_PATH", str(HAND))
    result = analyze_video(video, case["exercise"])
    cycle = result["cycles"][0]
    assert (cycle["label"], cycle["confidence"], result["measure"]["value"]) == (case["label"], case["confidence"], case["measure_value"])
    changed = [key for key, sha in case["field_sha256"].items() if key not in result or field_hash(result[key]) != sha]
    assert not changed, f"fields changed: {changed}"
