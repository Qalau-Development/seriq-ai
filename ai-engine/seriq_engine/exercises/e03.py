import numpy as np

from seriq_engine.angles import fill_gaps, smooth
from seriq_engine.features import compute_features
from seriq_engine.hand import MIDDLE_MCP, WRIST, HandTrack
from seriq_engine.video import VideoInfo

EXERCISE = "E03"
MEASURE = {"name": "wrist_lift", "unit": "deg"}
START_SHARE = 0.1


# raw_lift — поворот вектора запястье → середина ладони от начального направления, градусы, вверх положительно
def raw_lift(points: np.ndarray) -> np.ndarray:
    vec = points[:, MIDDLE_MCP] - points[:, WRIST]
    valid = np.flatnonzero(~np.isnan(vec[:, 0]))
    if len(valid) == 0:
        return np.full(len(points), np.nan)
    first = valid[: max(1, int(round(len(valid) * START_SHARE)))]
    dx = vec[:, 0] if np.median(vec[first, 0]) >= 0 else -vec[:, 0]
    angle = np.full(len(points), np.nan)
    angle[valid] = np.degrees(np.unwrap(np.arctan2(-vec[valid, 1], dx[valid])))
    return angle - angle[first].mean()


# signal — ряд подъёма кисти: расчёт, заполнение коротких пропусков, сглаживание
def signal(track: HandTrack, info: VideoInfo | None = None) -> np.ndarray:
    return smooth(fill_gaps(raw_lift(track.points)))


# features — относительные признаки цикла, те же формулы, что у E02
def features(series: np.ndarray, fps: float) -> dict[str, float]:
    return compute_features(series, fps)


# measure — максимальный подъём кисти от начала, градусы; None, если сигнала нет
def measure(series: np.ndarray) -> float | None:
    if np.all(np.isnan(series)):
        return None
    return round(float(np.nanmax(series)), 1)
