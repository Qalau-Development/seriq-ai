from pathlib import Path

import numpy as np

from seriq_engine.classifier import MIN_DETECTED_SHARE, decide, load_bundle, model_path, predict_complete, signal_quality
from seriq_engine.angles import MIN_POINTS
from seriq_engine.errors import ArmNotFound, VideoTooLong, VideoTooShort, VideoUnreadable
from seriq_engine.exercises import e02
from seriq_engine.exercises import MEASURES, get_module, is_ready, model_file
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
    for exercise in MEASURES:
        if exercise != "E02" and is_ready(exercise):
            load_bundle(str(model_file(exercise)))
    return load_bundle(model_path())["model_version"]


# chart_values — угол для графика: обрезка до 0–180°, округление, null без кисти
def chart_values(angles: np.ndarray) -> list[float | None]:
    return e02.chart_values(angles)


# plain_values — значения ряда для графика без обрезки, округление, null без кисти
def plain_values(series: np.ndarray) -> list[float | None]:
    return [None if np.isnan(v) else round(float(v), 1) for v in series]


# pose_payload — реальные точки кисти и найденный локоть в долях кадра, как видео видит пользователь; null без кисти
def pose_payload(track: HandTrack, elbow: np.ndarray | None, sample_fps: float) -> dict:
    size = np.array(track.frame_size, dtype=float)
    frames = []
    for t, points in zip(track.times, track.points):
        if np.isnan(points[WRIST, 0]):
            frames.append(None)
            continue
        share = np.round(points / size, 4)
        frames.append({"t": round(float(t), 4), "wrist": share[WRIST].tolist(), "hand": share.tolist()})
    payload = {"fps": round(sample_fps, 2), "frames": frames}
    if elbow is not None:
        payload = {"fps": payload["fps"], "elbow": np.round(elbow / size, 4).tolist(), "frames": frames}
    return payload


# analyze_video — анализирует видео одного повторения выбранного упражнения и возвращает результат по docs/api.md
def analyze_video(path: str | Path, exercise: str = "E02") -> dict:
    module = get_module(exercise, check_model=False)
    info = probe_video(path)
    if info.duration_s < MIN_DURATION_S:
        raise VideoTooShort(f"Video is {info.duration_s:.1f} s, minimum {MIN_DURATION_S:.0f} s")
    if info.duration_s > MAX_DURATION_S:
        raise VideoTooLong(f"Video is {info.duration_s:.1f} s, maximum {MAX_DURATION_S:.0f} s")
    get_module(exercise)
    bundle = load_bundle(str(model_file(exercise)))

    track = track_hand(path, info=info)
    if len(track.points) == 0:
        raise VideoUnreadable("No frames could be decoded")
    series = module.signal(track, info)
    if np.count_nonzero(~np.isnan(series)) < MIN_POINTS:
        raise ArmNotFound("Hand found in too few frames")
    quality = signal_quality(series, info.sample_fps)
    p_complete = predict_complete(bundle, module.features(series, info.sample_fps))
    label, confidence = decide(p_complete, quality.ok, bundle["confidence_threshold"])
    verdict = "completed" if label == "complete" else "check_instructions"

    valid = np.flatnonzero(~np.isnan(series))
    chart = module.chart(series) if hasattr(module, "chart") else plain_values(series)
    fps = round(info.sample_fps, 2)
    elbow = module.elbow(track) if getattr(module, "HAS_ELBOW", False) else None
    result = {
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
        "measure": {**MEASURES[exercise], "value": module.measure(series), "series": {"fps": fps, "values": chart}},
        "warnings": ["arm_not_visible"] if quality.detected_share < MIN_DETECTED_SHARE else [],
        "pose": pose_payload(track, elbow, info.sample_fps),
    }
    if exercise == "E02":
        result["angle_series"] = {"fps": fps, "unit": "deg", "values": chart}
    return result
