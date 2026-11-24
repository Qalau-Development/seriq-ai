import numpy as np
from scipy.optimize import least_squares

from seriq_engine.errors import ArmNotFound
from seriq_engine.hand import MIDDLE_MCP, WRIST

K_FOREARM = 3.56
MIN_POINTS = 10
MAX_GAP = 3


# elbow_center — локоть как центр окружности радиуса K_FOREARM × длина кисти через точки запястья
def elbow_center(points: np.ndarray) -> tuple[np.ndarray, float]:
    ok = ~np.isnan(points[:, WRIST, 0])
    wrist, mcp = points[ok, WRIST], points[ok, MIDDLE_MCP]
    hand_len = np.linalg.norm(mcp - wrist, axis=1)
    keep = hand_len > 0
    if keep.sum() < MIN_POINTS:
        raise ArmNotFound("Hand found in too few frames")
    wrist, mcp, hand_len = wrist[keep], mcp[keep], hand_len[keep]
    radius = float(K_FOREARM * np.median(hand_len))
    direction = (mcp - wrist) / hand_len[:, None]
    start = np.median(wrist - radius * direction, axis=0)
    fit = least_squares(lambda c: np.linalg.norm(wrist - c, axis=1) - radius, start)
    return fit.x, radius


# raw_angle_series — 180° минус наклон предплечья от горизонтали, NaN где кисти нет
def raw_angle_series(points: np.ndarray) -> np.ndarray:
    center, _ = elbow_center(points)
    dx = points[:, WRIST, 0] - center[0]
    dy = center[1] - points[:, WRIST, 1]
    if np.nanmedian(dx) < 0:
        dx = -dx
    return 180.0 - np.degrees(np.arctan2(dy, dx))


# fill_gaps — линейно заполняет внутренние пропуски не длиннее max_gap кадров
def fill_gaps(values: np.ndarray, max_gap: int = MAX_GAP) -> np.ndarray:
    out = values.copy()
    nan = np.isnan(out)
    i = 0
    while i < len(out):
        if not nan[i]:
            i += 1
            continue
        j = i
        while j < len(out) and nan[j]:
            j += 1
        if i > 0 and j < len(out) and j - i <= max_gap:
            out[i:j] = np.interp(np.arange(i, j), [i - 1, j], [out[i - 1], out[j]])
        i = j
    return out


# smooth — скользящее среднее по 3 кадрам без учёта пропусков
def smooth(values: np.ndarray) -> np.ndarray:
    padded = np.pad(values, 1, constant_values=np.nan)
    window = np.stack([padded[:-2], padded[1:-1], padded[2:]])
    count = (~np.isnan(window)).sum(axis=0)
    out = np.nan_to_num(window).sum(axis=0) / np.maximum(count, 1)
    out[np.isnan(values)] = np.nan
    return out


# elbow_angle_series — итоговый ряд угла локтя: расчёт, заполнение коротких пропусков, сглаживание
def elbow_angle_series(points: np.ndarray) -> np.ndarray:
    return smooth(fill_gaps(raw_angle_series(points)))
