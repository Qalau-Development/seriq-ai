import numpy as np

from seriq_engine.angles import fill_gaps, smooth
from seriq_engine.features import MIN_VALID, compute_features
from seriq_engine.hand import MIDDLE_MCP, WRIST, HandTrack
from seriq_engine.video import VideoInfo

EXERCISE = "E01"
MEASURE = {"name": "lift_height", "unit": "hand_lengths"}
START_SHARE = 0.1


# raw_lift — подъём запястья вверх от начала записи в длинах кисти
def raw_lift(points: np.ndarray) -> np.ndarray:
    wrist_y = points[:, WRIST, 1]
    hand_len = np.linalg.norm(points[:, MIDDLE_MCP] - points[:, WRIST], axis=1)
    valid = np.flatnonzero(~np.isnan(wrist_y) & ~np.isnan(hand_len))
    if len(valid) == 0 or np.median(hand_len[valid]) == 0:
        return np.full(len(points), np.nan)
    first = valid[: max(1, int(round(len(valid) * START_SHARE)))]
    return (wrist_y[first].mean() - wrist_y) / np.median(hand_len[valid])


# signal — ряд подъёма кисти: расчёт, заполнение коротких пропусков, сглаживание
def signal(track: HandTrack, info: VideoInfo | None = None) -> np.ndarray:
    return smooth(fill_gaps(raw_lift(track.points)))


# measure — максимальный подъём кисти от начала, длины кисти; None, если сигнала нет
def measure(series: np.ndarray) -> float | None:
    if np.all(np.isnan(series)):
        return None
    return round(float(np.nanmax(series)), 2)


# features — общие признаки цикла плюс свои: средний подъём, размах и доля времени выше одной длины кисти
def features(series: np.ndarray, fps: float) -> dict[str, float]:
    out = compute_features(series, fps)
    values = series[~np.isnan(series)]
    if len(values) < MIN_VALID:
        return out | {"lift_area": float("nan"), "lift_range": float("nan"), "lift_above1": float("nan")}
    return out | {
        "lift_area": float(values.clip(0).mean()),
        "lift_range": float(np.percentile(values, 95) - np.percentile(values, 5)),
        "lift_above1": float((values > 1.0).mean()),
    }
