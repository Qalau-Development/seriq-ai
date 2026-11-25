import os
from dataclasses import dataclass
from functools import lru_cache

import joblib
import numpy as np

from seriq_engine.features import feature_vector

DEFAULT_MODEL_PATH = "/srv/models/e02_classifier.joblib"
CONFIDENCE_THRESHOLD = 0.75
MIN_DETECTED_SHARE = 0.80
MAX_GAP_S = 2.0
MIN_VALID_POINTS = 20
MIN_SPAN_SHARE = 0.5


# SignalQuality — качество ряда угла: доля кадров, самый длинный пропуск, число точек
@dataclass(frozen=True)
class SignalQuality:
    detected_share: float
    longest_gap_s: float
    valid_points: int

    # ok — сигнал не хуже порогов, зафиксированных по train
    @property
    def ok(self) -> bool:
        return (
            self.detected_share >= MIN_DETECTED_SHARE
            and self.longest_gap_s <= MAX_GAP_S
            and self.valid_points >= MIN_VALID_POINTS
        )


# signal_quality — считает качество ряда от первого до последнего кадра с кистью; пустые начало и конец не штрафуются
def signal_quality(angles: np.ndarray, sample_fps: float) -> SignalQuality:
    found = np.flatnonzero(~np.isnan(angles))
    if len(found) == 0 or (found[-1] - found[0] + 1) < MIN_SPAN_SHARE * len(angles):
        return SignalQuality(detected_share=float(len(found) / max(len(angles), 1)), longest_gap_s=len(angles) / sample_fps, valid_points=len(found))
    valid = ~np.isnan(angles[found[0] : found[-1] + 1])
    longest = current = 0
    for v in valid:
        current = 0 if v else current + 1
        longest = max(longest, current)
    share = float(valid.mean()) if len(angles) else 0.0
    return SignalQuality(detected_share=share, longest_gap_s=longest / sample_fps, valid_points=int(valid.sum()))


# decide — метка и confidence по правилам api.md, uncertain при плохом сигнале или низкой уверенности
def decide(p_complete: float, quality_ok: bool, threshold: float = CONFIDENCE_THRESHOLD) -> tuple[str, float]:
    confidence = float(max(p_complete, 1.0 - p_complete))
    if not quality_ok or confidence < threshold:
        return "uncertain", confidence
    return ("complete" if p_complete >= 0.5 else "incomplete"), confidence


# model_path — путь к модели из SERIQ_MODEL_PATH
def model_path() -> str:
    return os.environ.get("SERIQ_MODEL_PATH", DEFAULT_MODEL_PATH)


# load_bundle — загружает модель один раз на процесс
@lru_cache(maxsize=2)
def load_bundle(path: str | None = None) -> dict:
    return joblib.load(path or model_path())


# predict_complete — вероятность complete по признакам цикла
def predict_complete(bundle: dict, features: dict[str, float]) -> float:
    x = feature_vector(features, bundle["features"]).reshape(1, -1)
    return float(bundle["model"].predict_proba(x)[0, 1])
