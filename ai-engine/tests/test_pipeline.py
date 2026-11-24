import os
import shutil
import subprocess
from pathlib import Path

import cv2
import numpy as np
import pytest

from seriq_engine.classifier import decide, load_bundle, predict_complete
from seriq_engine.errors import VideoTooLong, VideoTooShort, VideoUnreadable
from seriq_engine.features import compute_features
from seriq_engine.hand import HandTrack
from seriq_engine.pipeline import analyze_video, chart_values, pose_payload, warmup
from seriq_engine.video import VideoInfo
from seriq_engine.video import probe_video

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "models" / "e02_classifier.joblib"
LOCAL_HAND = ROOT / "data" / "processed" / "mp_models" / "hand_landmarker.task"
TRAIN_VIDEO = ROOT / "data/raw/An upper limb stroke rehabilitation exercise video/Exercise/2_Extending the Elbow/Complete/Train/01_02_01_01.mp4"


# write_video — синтетическое видео заданной длительности без руки
def write_video(path: Path, seconds: float, fps: int = 10) -> Path:
    writer = cv2.VideoWriter(str(path), cv2.VideoWriter_fourcc(*"mp4v"), fps, (64, 48))
    for _ in range(int(seconds * fps)):
        writer.write(np.full((48, 64, 3), 128, np.uint8))
    writer.release()
    return path


# test_too_short — видео короче 2 с даёт video_too_short
def test_too_short(tmp_path):
    with pytest.raises(VideoTooShort) as err:
        analyze_video(write_video(tmp_path / "short.mp4", 1))
    assert err.value.api_code == "video_too_short"


# test_too_long — видео длиннее 60 с даёт video_too_long
def test_too_long(tmp_path):
    with pytest.raises(VideoTooLong):
        analyze_video(write_video(tmp_path / "long.mp4", 61))


# test_unreadable — файл с мусором вместо видео даёт video_unreadable
def test_unreadable(tmp_path):
    bad = tmp_path / "bad.mp4"
    bad.write_bytes(b"\x00\x00\x00\x18ftypmp42" + b"\x00" * 200)
    with pytest.raises(VideoUnreadable):
        analyze_video(bad)


# test_webm_without_duration — webm из браузера без длительности читается по декодированию
@pytest.mark.skipif(shutil.which("ffmpeg") is None, reason="ffmpeg not installed")
def test_webm_without_duration(tmp_path):
    path = tmp_path / "live.webm"
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-f", "lavfi", "-i", "testsrc=size=320x240:rate=30", "-t", "4",
         "-c:v", "libvpx", "-live", "1", "-f", "webm", str(path)],
        check=True,
    )
    info = probe_video(path)
    assert info.frame_count == 120 and info.duration_s == pytest.approx(4.0, abs=0.1)


# test_chart_values — график обрезан до 0–180°, пропуски — null
def test_chart_values():
    assert chart_values(np.array([187.26, 95.04, np.nan, -3.0])) == [180.0, 95.0, None, 0.0]


# test_model_bundle — модель из models/ грузится и разделяет полный и неполный цикл
@pytest.mark.skipif(not MODEL.exists(), reason="model file not present")
def test_model_bundle():
    bundle = load_bundle(str(MODEL))
    complete = compute_features(np.r_[np.linspace(90, 178, 80), np.full(20, 178.0)], 10)
    incomplete = compute_features(np.r_[np.linspace(90, 130, 50), np.linspace(130, 92, 50)], 10)
    assert decide(predict_complete(bundle, complete), True, bundle["confidence_threshold"])[0] == "complete"
    assert decide(predict_complete(bundle, incomplete), True, bundle["confidence_threshold"])[0] == "incomplete"


# test_end_to_end — настоящее видео train даёт ответ по контракту (только локально, нужны веса и датасет)
@pytest.mark.skipif(not (LOCAL_HAND.exists() and TRAIN_VIDEO.exists()), reason="hand weights or dataset not present")
def test_end_to_end(monkeypatch):
    monkeypatch.setenv("SERIQ_HAND_MODEL_PATH", str(LOCAL_HAND))
    monkeypatch.setenv("SERIQ_MODEL_PATH", str(MODEL))
    result = analyze_video(TRAIN_VIDEO)
    assert set(result) == {"model_version", "verdict", "summary", "cycles", "angle_series", "warnings", "pose"}
    (cycle,) = result["cycles"]
    assert cycle["label"] == "complete" and result["verdict"] == "completed"
    assert 0 <= cycle["start_s"] < cycle["end_s"]
    values = [v for v in result["angle_series"]["values"] if v is not None]
    assert values and all(0 <= v <= 180 for v in values)
    assert os.environ["SERIQ_MODEL_PATH"] == str(MODEL)
    pose = result["pose"]
    assert pose["fps"] == result["angle_series"]["fps"] and len(pose["frames"]) == len(result["angle_series"]["values"])
    found = [f for f in pose["frames"] if f]
    assert found and all(len(f["hand"]) == 21 and f["wrist"] == f["hand"][0] for f in found)
    assert all(0 <= v <= 1 for f in found for p in f["hand"] for v in p)


# test_warmup — warmup загружает модель и создаёт HandLandmarker (только локально, нужны веса)
@pytest.mark.skipif(not LOCAL_HAND.exists(), reason="hand weights not present")
def test_warmup(monkeypatch):
    monkeypatch.setenv("SERIQ_HAND_MODEL_PATH", str(LOCAL_HAND))
    monkeypatch.setenv("SERIQ_MODEL_PATH", str(MODEL))
    assert warmup() == "e02-logreg2-1"


# test_warmup_without_weights — без весов кисти warmup падает сразу
def test_warmup_without_weights(monkeypatch, tmp_path):
    monkeypatch.setenv("SERIQ_HAND_MODEL_PATH", str(tmp_path / "missing.task"))
    with pytest.raises(FileNotFoundError):
        warmup()


# test_pose_payload — доли кадра с 4 знаками, null без кисти, t как у графика, локоть может выйти за 0–1
def test_pose_payload():
    points = np.full((3, 21, 2), np.nan)
    points[0] = [[100.0 + j, 50.0] for j in range(21)]
    points[2] = [[400.123456, 300.0]] * 21
    info = VideoInfo(fps=30.0, frame_count=9, duration_s=0.3, step=3, sample_fps=10.0)
    track = HandTrack(points=points, times=np.array([0.0, 0.1, 0.2]), info=info, frame_size=(400, 300))
    pose = pose_payload(track, np.array([-40.0, 330.0]), info.sample_fps)
    assert pose["fps"] == 10.0 and pose["elbow"] == [-0.1, 1.1]
    first, missing, last = pose["frames"]
    assert missing is None
    assert first["t"] == 0.0 and first["wrist"] == [0.25, 0.1667] and len(first["hand"]) == 21
    assert last["t"] == 0.2 and last["wrist"] == [1.0003, 1.0]
