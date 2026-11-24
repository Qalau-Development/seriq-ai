import numpy as np
import pytest

from seriq_engine.angles import K_FOREARM, ArmNotFound, elbow_angle_series, elbow_center, fill_gaps, raw_angle_series, smooth
from seriq_engine.hand import MIDDLE_MCP, WRIST

CENTER = np.array([100.0, 600.0])
HAND = 70.0


# synthetic_points — кисть на предплечье, повёрнутом на заданные наклоны вокруг локтя
def synthetic_points(tilts_deg, mirror=False):
    radius = K_FOREARM * HAND
    points = np.full((len(tilts_deg), 21, 2), np.nan)
    for i, tilt in enumerate(np.radians(tilts_deg)):
        direction = np.array([np.cos(tilt), -np.sin(tilt)])
        if mirror:
            direction[0] = -direction[0]
        points[i, WRIST] = CENTER + radius * direction
        points[i, MIDDLE_MCP] = CENTER + (radius + HAND) * direction
    return points


# test_center_full_arc — центр находится по полной дуге разгибания
def test_center_full_arc():
    center, radius = elbow_center(synthetic_points(np.linspace(90, 0, 40)))
    assert np.allclose(center, CENTER, atol=1.0)
    assert radius == pytest.approx(K_FOREARM * HAND)


# test_center_short_arc — центр находится и при малом движении руки
def test_center_short_arc():
    center, _ = elbow_center(synthetic_points(np.linspace(80, 70, 40)))
    assert np.allclose(center, CENTER, atol=1.0)


# test_angle_scale — прямая рука 180°, вертикальное предплечье 90°
def test_angle_scale():
    angles = raw_angle_series(synthetic_points(np.linspace(90, 0, 40)))
    assert angles[0] == pytest.approx(90, abs=0.5)
    assert angles[-1] == pytest.approx(180, abs=0.5)


# test_mirrored_arm — рука, направленная влево, даёт ту же шкалу
def test_mirrored_arm():
    angles = raw_angle_series(synthetic_points(np.linspace(90, 0, 40), mirror=True))
    assert angles[-1] == pytest.approx(180, abs=0.5)


# test_too_few_points — без кисти выбрасывается ArmNotFound
def test_too_few_points():
    with pytest.raises(ArmNotFound):
        elbow_center(np.full((50, 21, 2), np.nan))


# test_fill_gaps — короткие пропуски заполняются, длинные и краевые остаются
def test_fill_gaps():
    values = np.array([np.nan, 1, np.nan, 3, np.nan, np.nan, np.nan, np.nan, 8, np.nan])
    out = fill_gaps(values, max_gap=3)
    assert out[2] == pytest.approx(2)
    assert np.isnan(out[0]) and np.isnan(out[-1]) and np.isnan(out[5])


# test_smooth_keeps_nan — сглаживание не заполняет пропуски
def test_smooth_keeps_nan():
    out = smooth(np.array([1.0, 2.0, np.nan, 4.0]))
    assert out[0] == pytest.approx(1.5) and np.isnan(out[2])


# test_series_end_to_end — полный ряд с пропуском близок к истинному углу
def test_series_end_to_end():
    tilts = np.linspace(90, 0, 40)
    points = synthetic_points(tilts)
    points[10] = np.nan
    out = elbow_angle_series(points)
    assert np.nanmax(np.abs(out - (180 - tilts))) < 2.0
