import numpy as np
import pytest

from seriq_engine.exercises import e04
from seriq_engine.hand import HandTrack

TIPS = [4, 8, 12, 16, 20]


# make_track — синтетическая кисть: запястье на месте, кончики пальцев на расстоянии reach от запястья
def make_track(reach: np.ndarray, palm: float = 50.0, mirror: bool = False, rotate: float = 0.0) -> HandTrack:
    points = np.zeros((len(reach), 21, 2))
    points[:, 0] = [300.0, 400.0]
    turn = np.radians(rotate)
    direction = np.array([np.cos(turn), -np.sin(turn)])
    points[:, 9] = points[:, 0] + palm * direction
    for tip in TIPS:
        points[:, tip] = points[:, 0] + (reach * palm)[:, None] * direction
    if mirror:
        points[..., 0] = 640.0 - points[..., 0]
    return HandTrack(points=points, times=np.arange(len(reach)) / 10.0, info=None, frame_size=(640, 480))


# test_open_and_hold — раскрытие в 1,8 раза от начала и удержание: measure около 180
def test_open_and_hold():
    reach = np.r_[np.full(10, 1.0), np.linspace(1.0, 1.8, 40), np.full(30, 1.8)]
    series = e04.signal(make_track(reach))
    assert e04.measure(series) == pytest.approx(180, abs=1)
    assert e04.features(series, 10)["end_minus_start"] == pytest.approx(80, abs=1)


# test_scale_mirror_rotation_invariance — размер кисти, зеркало и поворот в кадре не меняют сигнал
def test_scale_mirror_rotation_invariance():
    reach = np.r_[np.full(10, 1.0), np.linspace(1.0, 1.6, 40)]
    a = e04.signal(make_track(reach))
    assert e04.signal(make_track(reach, palm=120.0)) == pytest.approx(a, abs=1e-6)
    assert e04.signal(make_track(reach, mirror=True)) == pytest.approx(a, abs=1e-6)
    assert e04.signal(make_track(reach, rotate=70.0)) == pytest.approx(a, abs=1e-6)


# test_open_then_close — раскрыл и сжал обратно: в конце сигнал вернулся к началу
def test_open_then_close():
    reach = np.r_[np.full(10, 1.0), np.linspace(1.0, 1.7, 30), np.linspace(1.7, 1.0, 30)]
    f = e04.features(e04.signal(make_track(reach)), 10)
    assert abs(f["end_minus_start"]) < 15


# test_no_hand — без кисти сигнал пустой, measure None
def test_no_hand():
    track = make_track(np.ones(30))
    track.points[:] = np.nan
    series = e04.signal(track)
    assert np.all(np.isnan(series))
    assert e04.measure(series) is None
