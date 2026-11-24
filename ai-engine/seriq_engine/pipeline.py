from pathlib import Path

import numpy as np

from seriq_engine.angles import elbow_angle_series, elbow_center
from seriq_engine.classifier import MIN_DETECTED_SHARE, decide, load_bundle, model_path, predict_complete, signal_quality
from seriq_engine.errors import VideoTooLong, VideoTooShort, VideoUnreadable
from seriq_engine.features import compute_features
from seriq_engine.hand import WRIST, HandTrack, create_landmarker, hand_model_path, track_hand
from seriq_engine.video import probe_video

MIN_DURATION_S = 2.0
MAX_DURATION_S = 60.0


# warmup — при старте бэкенда загружает модель и создаёт HandLandmarker, чтобы ошибки среды всплыли сразу
def warmup() -> str:
    if not Path(hand_model_path()).is_file():
        raise FileNotFoundError(f"Hand landmarker weights not found: {hand_model_path()}")
    with create_landmarker():
        pass
    return load_bundle(model_path())["model_version"]


# chart_values — угол для графика: обрезка до 0–180°, округление, null без кисти
def chart_values(angles: np.ndarray) -> list[float | None]:
    return [None if np.isnan(a) else round(float(np.clip(a, 0.0, 180.0)), 1) for a in angles]


# pose_payload — реальные точки кисти и найденный локоть в долях кадра, как видео видит пользователь; null без кисти
def pose_payload(track: HandTrack, elbow: np.ndarray, sample_fps: float) -> dict:
    size = np.array(track.frame_size, dtype=float)
    frames = []
    for t, points in zip(track.times, track.points):
        if np.isnan(points[WRIST, 0]):
            frames.append(None)
            continue
        share = np.round(points / size, 4)
        frames.append({"t": round(float(t), 4), "wrist": share[WRIST].tolist(), "hand": share.tolist()})
    return {"fps": round(sample_fps, 2), "elbow": np.round(elbow / size, 4).tolist(), "frames": frames}


# analyze_video — анализирует видео одного повторения и возвращает результат по docs/api.md
def analyze_video(path: str | Path) -> dict:
    info = probe_video(path)
    if info.duration_s < MIN_DURATION_S:
        raise VideoTooShort(f"Video is {info.duration_s:.1f} s, minimum {MIN_DURATION_S:.0f} s")
    if info.duration_s > MAX_DURATION_S:
        raise VideoTooLong(f"Video is {info.duration_s:.1f} s, maximum {MAX_DURATION_S:.0f} s")
    bundle = load_bundle(model_path())

    track = track_hand(path, info=info)
    if len(track.points) == 0:
        raise VideoUnreadable("No frames could be decoded")
    angles = elbow_angle_series(track.points)
    quality = signal_quality(angles, info.sample_fps)
    p_complete = predict_complete(bundle, compute_features(angles, info.sample_fps))
    label, confidence = decide(p_complete, quality.ok, bundle["confidence_threshold"])
    verdict = "completed" if label == "complete" else "check_instructions"

    valid = np.flatnonzero(~np.isnan(angles))
    return {
        "model_version": bundle["model_version"],
        "verdict": verdict,
        "summary": {
            "total": 1,
            "complete": int(label == "complete"),
            "incomplete": int(label == "incomplete"),
            "uncertain": int(label == "uncertain"),
        },
        "cycles": [
            {
                "index": 1,
                "start_s": round(float(track.times[valid[0]]), 2),
                "end_s": round(float(track.times[valid[-1]]), 2),
                "label": label,
                "confidence": round(confidence, 3),
                "verdict": verdict,
            }
        ],
        "angle_series": {"fps": round(info.sample_fps, 2), "unit": "deg", "values": chart_values(angles)},
        "warnings": ["arm_not_visible"] if quality.detected_share < MIN_DETECTED_SHARE else [],
        "pose": pose_payload(track, elbow_center(track.points)[0], info.sample_fps),
    }
