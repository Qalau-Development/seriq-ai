import numpy as np
import pytest

from seriq_engine.exercises import e01
from seriq_engine.hand import HandTrack


# make_track — синтетическая кисть: запястье поднимается на lift длин кисти от начала
def make_track(lift: np.ndarray, hand_len: float = 50.0, mirror: bool = False) -> HandTrack:
    points = np.zeros((len(lift), 21, 2))
    points[:, 0, 0] = 300.0
    points[:, 0, 1] = 400.0 - lift * hand_len
    points[:, 9, 0] = 300.0 + hand_len
    points[:, 9, 1] = points[:, 0, 1]
    if mirror:
        points[..., 0] = 640.0 - points[..., 0]
    return HandTrack(points=points, times=np.arange(len(lift)) / 10.0, info=None, frame_size=(640, 480))


# test_lift_height — подъём на 3 длины кисти: measure около 3
def test_lift_height():
    lift = np.r_[np.zeros(10), np.linspace(0, 3, 30), np.full(20, 3.0), np.linspace(3, 0, 30)]
    series = e01.signal(make_track(lift))
    assert e01.measure(series) == pytest.approx(3, abs=0.1)
    assert e01.features(series, 10)["lift_area"] > 1


# test_scale_invariance — размер кисти в кадре не меняет сигнал
def test_scale_invariance():
    lift = np.r_[np.zeros(10), np.linspace(0, 2, 40)]
    a = e01.signal(make_track(lift, hand_len=30.0))
    b = e01.signal(make_track(lift, hand_len=120.0))
    assert b == pytest.approx(a, abs=1e-6)


# test_mirrored_side — рука с другой стороны кадра даёт тот же сигнал
def test_mirrored_side():
    lift = np.r_[np.zeros(10), np.linspace(0, 2, 40), np.linspace(2, 0, 40)]
    assert e01.signal(make_track(lift, mirror=True)) == pytest.approx(e01.signal(make_track(lift)), abs=1e-6)


# test_no_hand — без кисти сигнал пустой, measure None, признаки NaN
def test_no_hand():
    track = make_track(np.zeros(30))
    track.points[:] = np.nan
    series = e01.signal(track)
    assert np.all(np.isnan(series))
    assert e01.measure(series) is None
    assert np.isnan(e01.features(series, 10)["lift_area"])
