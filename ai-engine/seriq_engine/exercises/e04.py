import numpy as np

from seriq_engine.angles import fill_gaps, smooth
from seriq_engine.features import compute_features
from seriq_engine.hand import MIDDLE_MCP, WRIST, HandTrack
from seriq_engine.video import VideoInfo

EXERCISE = "E04"
START_SHARE = 0.1
FINGERTIPS = [4, 8, 12, 16, 20]


# raw_openness — среднее расстояние кончиков пальцев до запястья / размер ладони, в процентах от начала записи
def raw_openness(points: np.ndarray) -> np.ndarray:
    wrist = points[:, WRIST]
    palm = np.linalg.norm(points[:, MIDDLE_MCP] - wrist, axis=1)
    palm[palm == 0] = np.nan
    reach = np.mean([np.linalg.norm(points[:, tip] - wrist, axis=1) for tip in FINGERTIPS], axis=0) / palm
    valid = np.flatnonzero(~np.isnan(reach))
    if len(valid) == 0:
        return np.full(len(points), np.nan)
    first = valid[: max(1, int(round(len(valid) * START_SHARE)))]
    return 100.0 * reach / reach[first].mean()


# signal — ряд раскрытия кисти: расчёт, заполнение коротких пропусков, сглаживание
def signal(track: HandTrack, info: VideoInfo | None = None) -> np.ndarray:
    return smooth(fill_gaps(raw_openness(track.points)))


# features — относительные признаки цикла, те же формулы, что у E02
def features(series: np.ndarray, fps: float) -> dict[str, float]:
    return compute_features(series, fps)


# measure — максимальное раскрытие кисти относительно начала, проценты; None, если сигнала нет
def measure(series: np.ndarray) -> float | None:
    if np.all(np.isnan(series)):
        return None
    return round(float(np.nanmax(series)), 1)
