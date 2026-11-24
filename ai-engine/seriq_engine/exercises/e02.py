import numpy as np

from seriq_engine.angles import elbow_angle_series, elbow_center
from seriq_engine.features import compute_features

EXERCISE = "E02"
HAS_ELBOW = True


# chart_values — угол для графика: обрезка до 0–180°, округление, null без кисти
def chart_values(angles: np.ndarray) -> list[float | None]:
    return [None if np.isnan(a) else round(float(np.clip(a, 0.0, 180.0)), 1) for a in angles]


# signal — ряд угла локтя по точкам кисти
def signal(track, info=None) -> np.ndarray:
    return elbow_angle_series(track.points)


# features — относительные признаки цикла по ряду угла
def features(series: np.ndarray, fps: float) -> dict[str, float]:
    return compute_features(series, fps)


# measure — максимальный угол локтя, как на графике; None, если сигнала нет
def measure(series: np.ndarray) -> float | None:
    known = [v for v in chart_values(series) if v is not None]
    return max(known) if known else None


# chart — значения для графика ответа
def chart(series: np.ndarray) -> list[float | None]:
    return chart_values(series)


# elbow — найденный локоть в пикселях кадра для линии руки
def elbow(track) -> np.ndarray:
    return elbow_center(track.points)[0]
