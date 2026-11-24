import numpy as np
import pytest

from seriq_engine.features import FEATURE_NAMES, compute_features, feature_vector


# test_complete_cycle — полный цикл: рука разогнулась и осталась прямой
def test_complete_cycle():
    angles = np.r_[np.linspace(90, 178, 80), np.full(20, 178.0)]
    f = compute_features(angles, sample_fps=10)
    start = angles[:10].mean()
    assert f["extension_range"] == pytest.approx(178 - start, abs=0.5)
    assert f["return_from_peak"] == pytest.approx(0, abs=1)
    assert f["hold_at_end"] == pytest.approx(1.0)


# test_incomplete_cycle — неполный цикл: рука поднялась и вернулась
def test_incomplete_cycle():
    angles = np.r_[np.linspace(90, 130, 50), np.linspace(130, 92, 50)]
    f = compute_features(angles, sample_fps=10)
    assert f["return_from_peak"] > 30
    assert f["hold_at_end"] < 0.2
    assert 0.4 < f["time_to_peak"] < 0.6


# test_camera_tilt_invariance — сдвиг всего ряда (наклон камеры) не меняет признаки
def test_camera_tilt_invariance():
    angles = np.r_[np.linspace(90, 130, 50), np.linspace(130, 92, 50)]
    a, b = compute_features(angles, 10), compute_features(angles + 12, 10)
    assert feature_vector(a) == pytest.approx(feature_vector(b))


# test_speed_uses_fps — скорость в градусах в секунду не зависит от частоты кадров
def test_speed_uses_fps():
    slow = compute_features(np.linspace(90, 180, 100), sample_fps=10)
    fast = compute_features(np.linspace(90, 180, 50), sample_fps=5)
    assert slow["max_rise_speed"] == pytest.approx(fast["max_rise_speed"], rel=0.05)


# test_no_hand — без кисти признаки пустые, доля найденной кисти 0
def test_no_hand():
    f = compute_features(np.full(30, np.nan), sample_fps=10)
    assert f["detected_share"] == 0 and np.isnan(f["extension_range"])
    assert len(feature_vector(f)) == len(FEATURE_NAMES)
