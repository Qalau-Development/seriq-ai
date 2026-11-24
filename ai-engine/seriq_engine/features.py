import numpy as np

EDGE_SHARE = 0.1
HOLD_SHARE = 0.2
HOLD_TOLERANCE_DEG = 10.0
MIN_VALID = 5

FEATURE_NAMES = [
    "extension_range",
    "total_range",
    "return_from_peak",
    "end_minus_start",
    "time_to_peak",
    "hold_at_end",
    "max_rise_speed",
    "max_fall_speed",
    "detected_share",
]
MODEL_FEATURES = ["extension_range", "end_minus_start"]


# compute_features — относительные признаки цикла по ряду угла локтя (не зависят от наклона камеры)
def compute_features(angles: np.ndarray, sample_fps: float) -> dict[str, float]:
    valid = ~np.isnan(angles)
    features = {name: float("nan") for name in FEATURE_NAMES}
    features["detected_share"] = float(valid.mean()) if len(angles) else 0.0
    if valid.sum() < MIN_VALID:
        return features

    values = angles[valid]
    position = np.flatnonzero(valid) / max(len(angles) - 1, 1)
    edge = max(1, int(round(len(values) * EDGE_SHARE)))
    start, end = values[:edge].mean(), values[-edge:].mean()
    peak, trough = np.percentile(values, 95), np.percentile(values, 5)

    tail = values[-max(1, int(round(len(values) * HOLD_SHARE))):]
    speed = np.diff(angles) * sample_fps

    features.update(
        extension_range=float(peak - start),
        total_range=float(peak - trough),
        return_from_peak=float(peak - end),
        end_minus_start=float(end - start),
        time_to_peak=float(position[np.argmax(values)]),
        hold_at_end=float((tail >= peak - HOLD_TOLERANCE_DEG).mean()),
        max_rise_speed=float(np.nanmax(speed)) if np.any(~np.isnan(speed)) else float("nan"),
        max_fall_speed=float(-np.nanmin(speed)) if np.any(~np.isnan(speed)) else float("nan"),
    )
    return features


# feature_vector — признаки в порядке FEATURE_NAMES для модели
def feature_vector(features: dict[str, float], names: list[str] = FEATURE_NAMES) -> np.ndarray:
    return np.array([features[name] for name in names], dtype=float)
