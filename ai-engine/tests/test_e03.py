import numpy as np
import pytest

from seriq_engine.exercises import e03
from seriq_engine.hand import HandTrack


# make_track — синтетическая кисть: запястье на месте, середина ладони поворачивается вверх на lift градусов
def make_track(lift: np.ndarray, start_deg: float = -20.0, hand_len: float = 50.0, mirror: bool = False) -> HandTrack:
    points = np.zeros((len(lift), 21, 2))
    angle = np.radians(start_deg + lift)
    points[:, 0] = [300.0, 400.0]
    points[:, 9, 0] = 300.0 + hand_len * np.cos(angle)
    points[:, 9, 1] = 400.0 - hand_len * np.sin(angle)
    if mirror:
        points[..., 0] = 640.0 - points[..., 0]
    return HandTrack(points=points, times=np.arange(len(lift)) / 10.0, info=None, frame_size=(640, 480))


# test_lift_and_hold — подъём на 90° и удержание: сигнал растёт до 90, measure около 90
def test_lift_and_hold():
    lift = np.r_[np.zeros(10), np.linspace(0, 90, 60), np.full(30, 90.0)]
    series = e03.signal(make_track(lift))
    assert e03.measure(series) == pytest.approx(90, abs=1)
    f = e03.features(series, 10)
    assert f["end_minus_start"] == pytest.approx(90, abs=1)


# test_mirrored_side — рука с другой стороны кадра даёт тот же сигнал, подъём остаётся положительным
def test_mirrored_side():
    lift = np.r_[np.zeros(10), np.linspace(0, 50, 40), np.linspace(50, 0, 40)]
    a = e03.signal(make_track(lift))
    b = e03.signal(make_track(lift, mirror=True))
    assert np.nanmax(b) == pytest.approx(50, abs=1)
    assert b == pytest.approx(a, abs=1e-6)


# test_scale_and_start_invariance — размер кисти в кадре и начальный наклон не меняют сигнал
def test_scale_and_start_invariance():
    lift = np.r_[np.zeros(10), np.linspace(0, 70, 50)]
    a = e03.signal(make_track(lift, start_deg=-40.0, hand_len=30.0))
    b = e03.signal(make_track(lift, start_deg=-5.0, hand_len=120.0))
    assert b == pytest.approx(a, abs=1e-6)


# test_no_hand — без кисти сигнал пустой, measure None
def test_no_hand():
    track = make_track(np.zeros(30))
    track.points[:] = np.nan
    series = e03.signal(track)
    assert np.all(np.isnan(series))
    assert e03.measure(series) is None
